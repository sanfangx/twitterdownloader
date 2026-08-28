import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twitter Image Downloader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isAuthenticated = false;
  String? _authToken;
  String? _ct0;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('tw_auth_token');
      _ct0 = prefs.getString('tw_ct0');
      _isAuthenticated = _authToken != null && _ct0 != null;
    });
  }

  void _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tw_auth_token');
    await prefs.remove('tw_ct0');
    setState(() {
      _isAuthenticated = false;
      _authToken = null;
      _ct0 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twitter 原图下载器配置'),
        actions: [
          if (_isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _clearAuth,
              tooltip: '清除配置',
            )
        ],
      ),
      body: Center(
        child: _isAuthenticated
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 80),
                  const SizedBox(height: 20),
                  const Text('✅ 配置成功，状态良好', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  const Text('您可以直接去推特分享推文进行下载了',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  Text('Auth Token: ${_authToken?.substring(0, 5)}...'),
                  Text('CT0: ${_ct0?.substring(0, 5)}...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange, size: 80),
                  const SizedBox(height: 20),
                  const Text('未配置凭证', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 10),
                  const Text('需要先登录您的推特账号提取凭证\n此操作只需进行一次，凭证仅保存在您的手机上',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginWebView(),
                        ),
                      );
                      if (result == true) {
                        _checkAuthStatus();
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('前往登录提取 Cookie'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

class LoginWebView extends StatefulWidget {
  const LoginWebView({super.key});

  @override
  State<LoginWebView> createState() => _LoginWebViewState();
}

class _LoginWebViewState extends State<LoginWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _extractCookies();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://twitter.com/login'));
  }

  Future<void> _extractCookies() async {
    try {
      final String cookiesStr = await _controller.runJavaScriptReturningResult(
          'document.cookie') as String;
      
      // Remove quotes around the cookie string if they exist
      final String cleanCookies = cookiesStr.replaceAll('"', '');
      
      String? authToken;
      String? ct0;
      
      final parts = cleanCookies.split(';');
      for (final part in parts) {
        final pair = part.trim().split('=');
        if (pair.length == 2) {
          if (pair[0] == 'auth_token') {
            authToken = pair[1];
          } else if (pair[0] == 'ct0') {
            ct0 = pair[1];
          }
        }
      }
      
      if (authToken != null && ct0 != null) {
        final prefs = await SharedPreferences.getInstance();
        // NOTE: For true iOS App Group support, you need to use a plugin that supports iOS UserDefaults suiteName.
        // Flutter's shared_preferences doesn't easily support App Groups by default,
        // often requiring flutter_secure_storage or a custom MethodChannel or a specific plugin like `shared_preference_app_group`.
        // For simplicity in this demo, we save it normally, but in production, we should map this to App Group.
        await prefs.setString('tw_auth_token', authToken);
        await prefs.setString('tw_ct0', ct0);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('凭证提取成功！')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("Cookie extraction error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 Twitter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
