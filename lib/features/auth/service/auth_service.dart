import 'dart:convert';

import 'package:demo_p/core/config/app_config.dart';
import 'package:demo_p/features/auth/model/auth_session.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RequiresConfirmationException implements Exception {
  const RequiresConfirmationException(this.username);

  final String username;

  @override
  String toString() => 'Switch device confirmation required.';
}

class AuthService {
  AuthService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  static const _sessionKey = 'auth_session';

  final Dio _dio;
  final CookieJar _cookieJar = CookieJar();

  Future<AuthSession?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_sessionKey);
    if (saved == null || saved.isEmpty) return null;

    try {
      final session = AuthSession.decode(saved);
      return session.hasToken ? session : null;
    } catch (_) {
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    required String captchaToken,
    String userTimezone = 'Asia/Calcutta',
    bool confirmExistingSession = false,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();
    final requestBody = {
      'captchaToken': captchaToken,
      'password': trimmedPassword,
      'userTimezone': userTimezone,
      'username': trimmedUsername,
      if (confirmExistingSession) ...{
        'requiresConfirmation': true,
        'confirmExistingSession': true,
        'forceLogin': true,
      },
    };
    final tokenPreview = captchaToken.substring(
      0,
      captchaToken.length < 20 ? captchaToken.length : 20,
    );
    debugPrint(
      '[AUTH] request body:'
      '\n  username     : ${requestBody['username']}'
      '\n  password     : ********'
      '\n  userTimezone : ${requestBody['userTimezone']}'
      '\n  captchaToken : $tokenPreview...',
    );

    final response = await _dio.post(
      AppConfig.loginUri.toString(),
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: _browserHeaders(contentType: 'application/json'),
      ),
      data: jsonEncode(requestBody),
    );
    debugPrint(
      '[AUTH] status: ${response.statusCode} | body: ${response.data}',
    );

    final responseBody = _decodeResponse(
      response.data is String ? response.data : jsonEncode(response.data),
    );

    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw AuthException(
        _messageFromResponse(responseBody) ?? 'Login failed. Please try again.',
      );
    }

    if (_requiresConfirmation(responseBody) && !confirmExistingSession) {
      throw RequiresConfirmationException(trimmedUsername);
    }

    final cookieHeader =
        await _cookieHeaderFor(AppConfig.loginUri) ??
        _cookieHeaderFromResponse(response);
    if (cookieHeader == null || cookieHeader.isEmpty) {
      debugPrint(
        '[AUTH] login response did not expose a session cookie; continuing with login response data.',
      );
    } else {
      debugPrint(
        '[AUTH] saved session cookie: ${cookieHeader.split(';').first}',
      );
    }

    Map<String, dynamic> mergedBody = responseBody;
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      try {
        final userData = await _fetchUserData(cookieHeader);
        debugPrint('[AUTH] fetched user data: $userData');
        mergedBody = {...responseBody, ...userData};
      } catch (e) {
        debugPrint('[AUTH] getUserData failed, using login response only: $e');
      }
    }

    final session = AuthSession(
      username: trimmedUsername,
      userTimezone: userTimezone,
      rawResponse: mergedBody,
      cookieHeader: cookieHeader,
    );
    await _loadFeatureFlags(session);
    debugPrint(
      '[AUTH] session role: ${session.role} | saved: ${jsonEncode(mergedBody)}',
    );
    await saveSession(session);
    return session;
  }

  /// GET /users/getUserData — fetches full user profile after login.
  Future<Map<String, dynamic>> _fetchUserData(String cookieHeader) async {
    final res = await _dio.get(
      AppConfig.userDataUri.toString(),
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {..._browserHeaders(), 'Cookie': cookieHeader},
      ),
    );
    debugPrint(
      '[AUTH] getUserData status: ${res.statusCode} | body: ${res.data}',
    );
    if (res.statusCode == null ||
        res.statusCode! < 200 ||
        res.statusCode! >= 300) {
      throw Exception('getUserData HTTP ${res.statusCode}');
    }
    return _decodeResponse(
      res.data is String ? res.data : jsonEncode(res.data),
    );
  }

  Future<void> _loadFeatureFlags(AuthSession session) async {
    final role = session.role;
    final userId = session.userId;
    if (role == null ||
        userId == null ||
        (role != 'patient' && role != 'therapist')) {
      return;
    }

    try {
      final res = await _dio.get(
        AppConfig.featureFlagUri(userId, role).toString(),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {
            ..._browserHeaders(),
            if (session.cookieHeader?.isNotEmpty ?? false)
              'Cookie': session.cookieHeader!,
          },
        ),
      );
      debugPrint('[AUTH] featureFlag status: ${res.statusCode}');
    } catch (error) {
      debugPrint('[AUTH] featureFlag failed: $error');
    }
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, session.encode());
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final session = await readSession();
    try {
      await _dio.post(
        AppConfig.logoutUri.toString(),
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {
            ..._browserHeaders(),
            if (session?.cookieHeader?.isNotEmpty ?? false)
              'Cookie': session!.cookieHeader!,
          },
        ),
        data: jsonEncode(<String, dynamic>{}),
      );
    } catch (error) {
      debugPrint('[AUTH] logout request failed: $error');
    }
    await _cookieJar.deleteAll();
    await prefs.remove(_sessionKey);
  }

  Future<String?> _cookieHeaderFor(Uri uri) async {
    final cookies = await _cookieJar.loadForRequest(uri);
    if (cookies.isEmpty) return null;
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Map<String, String> _browserHeaders({String? contentType}) {
    return {
      'Accept': 'application/json, text/plain, */*',
      'Origin': AppConfig.baseUrl,
      'Referer': '${AppConfig.baseUrl}/',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      if (contentType != null) 'Content-Type': contentType,
    };
  }

  String? _cookieHeaderFromResponse(Response<dynamic> response) {
    final values = response.headers.map['set-cookie'];
    if (values == null || values.isEmpty) return null;

    final cookies = values
        .map((value) => value.split(';').first.trim())
        .where((value) => value.isNotEmpty && value.contains('='))
        .toList();
    if (cookies.isEmpty) return null;

    return cookies.join('; ');
  }

  Map<String, dynamic> _decodeResponse(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return {'data': decoded};
  }

  String? _messageFromResponse(Map<String, dynamic> response) {
    const messageKeys = ['message', 'error', 'detail'];
    for (final key in messageKeys) {
      final message = response[key]?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  bool _requiresConfirmation(Map<String, dynamic> response) {
    final value = response['requiresConfirmation'];
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }
}
