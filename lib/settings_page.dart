import 'package:shared_preference_app_group/shared_preference_app_group.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

const String appGroupId = 'group.com.trollstore.twitterdownloader';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isAuthenticated = false;
  String? _authToken;
  String? _ct0;

  @override
  void initState() {
    super.initState();
    _initAppGroup();
    _checkAuthStatus();
  }

  Future<void> _initAppGroup() async {
    try {
      await SharedPreferenceAppGroup.setAppGroup(appGroupId);
    } catch (e) {
      debugPrint('Error setting app group: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authToken = prefs.getString('tw_auth_token');
      _ct0 = prefs.getString('tw_ct0');
      _isAuthenticated = _authToken != null && _ct0 != null;
    });
  }

  Future<void> _clearAuth() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后需要重新登录才能下载图片'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tw_auth_token');
      await prefs.remove('tw_ct0');
      
      try {
        await SharedPreferenceAppGroup.remove('tw_auth_token');
        await SharedPreferenceAppGroup.remove('tw_ct0');
      } catch (e) {
        debugPrint('Error removing from app group: $e');
      }
      
      setState(() {
        _isAuthenticated = false;
        _authToken = null;
        _ct0 = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // ---- Account section ----
          _buildSectionHeader('账号'),
          ListTile(
            leading: Icon(
              _isAuthenticated ? Icons.check_circle : Icons.error_outline,
              color: _isAuthenticated ? Colors.greenAccent : Colors.orange,
            ),
            title: Text(_isAuthenticated ? '已登录 Twitter' : '未登录'),
            subtitle: Text(
              _isAuthenticated
                  ? 'Auth Token: ${_authToken!.substring(0, 8)}...'
                  : '需要登录才能下载图片',
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _isAuthenticated
                ? OutlinedButton.icon(
                    onPressed: _clearAuth,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('退出登录'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginWebView()),
                      );
                      if (result == true) {
                        _checkAuthStatus();
                      }
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('登录 Twitter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
          ),
          const Divider(height: 32),

          // ---- About section ----
          _buildSectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.white54),
            title: Text('Twitter 原图下载器'),
            subtitle: Text('v1.0.0', style: TextStyle(color: Colors.white38)),
          ),
          const ListTile(
            leading: Icon(Icons.description_outlined, color: Colors.white54),
            title: Text('使用说明'),
            subtitle: Text(
              '1. 在设置中登录 Twitter 账号\n'
              '2. 在下载页面粘贴推文链接\n'
              '3. 点击「解析」预览并选择图片\n'
              '4. 点击「下载」保存原图到相册\n\n'
              '也可以从推特分享推文到本软件直接下载',
              style: TextStyle(color: Colors.white38, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.blue,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---- Login WebView ----

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
      ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _extractCookies();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('页面加载失败: ${error.description}')),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://twitter.com/login'));
  }

  Future<void> _extractCookies() async {
    try {
      final cookieManager = WebviewCookieManager();
      final gotCookies =
          await cookieManager.getCookies('https://twitter.com');
      final xCookies = await cookieManager.getCookies('https://x.com');

      final allCookies = [...gotCookies, ...xCookies];

      String? authToken;
      String? ct0;

      for (var cookie in allCookies) {
        if (cookie.name == 'auth_token') {
          authToken = cookie.value;
        } else if (cookie.name == 'ct0') {
          ct0 = cookie.value;
        }
      }

      if (authToken != null && ct0 != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tw_auth_token', authToken);
        await prefs.setString('tw_ct0', ct0);

        try {
          await SharedPreferenceAppGroup.setString('tw_auth_token', authToken);
          await SharedPreferenceAppGroup.setString('tw_ct0', ct0);
        } catch (e) {
          debugPrint('Error saving to app group: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 凭证提取成功！'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Cookie extraction error: $e');
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
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
