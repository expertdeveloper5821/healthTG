import 'package:demo_p/core/services/heartbeat_service.dart';
import 'package:demo_p/features/auth/model/auth_session.dart';
import 'package:demo_p/features/auth/service/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider(AuthService(), HeartbeatService())..loadSession();
});

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._heartbeatService);

  final AuthService _authService;
  final HeartbeatService _heartbeatService;

  AuthSession? session;
  bool isLoading = true;
  bool isSubmitting = false;
  bool requiresConfirmation = false;
  String? confirmationUsername;
  String? errorMessage;

  /// True when the server invalidated this session because the user
  /// logged in on another device. AuthGate watches this to show the popup.
  bool isSessionDisplaced = false;

  bool get isAuthenticated => session?.hasToken ?? false;

  Future<void> loadSession() async {
    isLoading = true;
    requiresConfirmation = false;
    confirmationUsername = null;
    errorMessage = null;
    notifyListeners();

    session = await _authService.readSession();
    if (session != null && (session!.cookieHeader?.isNotEmpty ?? false)) {
      _startHeartbeat(session!.cookieHeader!);
    }
    isLoading = false;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
    required String captchaToken,
    String userTimezone = 'Asia/Calcutta',
    bool confirmExistingSession = false,
  }) async {
    isSubmitting = true;
    requiresConfirmation = false;
    confirmationUsername = null;
    errorMessage = null;
    notifyListeners();

    try {
      session = await _authService.login(
        username: username,
        password: password,
        captchaToken: captchaToken,
        userTimezone: userTimezone,
        confirmExistingSession: confirmExistingSession,
      );
      debugPrint(
        '[AUTH] login success: role=${session?.role}, isTherapist=${session?.isTherapist}',
      );
      if (session != null && (session!.cookieHeader?.isNotEmpty ?? false)) {
        _startHeartbeat(session!.cookieHeader!);
      }
      return true;
    } on RequiresConfirmationException catch (error) {
      requiresConfirmation = true;
      confirmationUsername = error.username;
      errorMessage = null;
      return false;
    } on AuthException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (error) {
      debugPrint('[AUTH] unexpected login error: $error');
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _heartbeatService.stop();
    await _authService.logout();
    session = null;
    isSessionDisplaced = false;
    requiresConfirmation = false;
    confirmationUsername = null;
    notifyListeners();
  }

  void _startHeartbeat(String cookieHeader) {
    _heartbeatService.start(
      cookieHeader: cookieHeader,
      onSessionDisplaced: _onSessionDisplaced,
    );
  }

  void _onSessionDisplaced() {
    isSessionDisplaced = true;
    notifyListeners();
  }
}
