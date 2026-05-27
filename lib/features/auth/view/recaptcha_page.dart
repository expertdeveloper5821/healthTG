import 'package:demo_p/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RecaptchaPage extends StatefulWidget {
  const RecaptchaPage({super.key});

  @override
  State<RecaptchaPage> createState() => _RecaptchaPageState();
}

class _RecaptchaPageState extends State<RecaptchaPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E2021))
      ..addJavaScriptChannel(
        'Captcha',
        onMessageReceived: (message) {
          final token = message.message.trim();
          if (token.isEmpty || !mounted || _isCompleted) return;

          setState(() => _isCompleted = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(token);
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadHtmlString(_captchaHtml, baseUrl: AppConfig.recaptchaOrigin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2021),
      appBar: AppBar(title: const Text('Verify')),
      body: Stack(
        children: [
          if (!_isCompleted) WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  String get _captchaHtml {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://www.google.com/recaptcha/api.js?render=${AppConfig.captchaClientKey}"></script>
  <style>
    html, body {
      height: 100%;
      margin: 0;
      background: #1E2021;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    p { font-size: 16px; opacity: 0.7; }
  </style>
</head>
<body>
  <p>Verifying, please wait…</p>
  <script>
    grecaptcha.ready(function() {
      grecaptcha.execute('${AppConfig.captchaClientKey}', { action: 'login' })
        .then(function(token) {
          Captcha.postMessage(token);
        });
    });
  </script>
</body>
</html>
''';
  }
}
