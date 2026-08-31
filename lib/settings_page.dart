import 'package:shared_preference_app_group/shared_preference_app_group.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'extension_log_page.dart';

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
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader('账号'),
          _buildCard(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _isAuthenticated ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isAuthenticated ? Icons.person : Icons.person_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(_isAuthenticated ? '已登录 Twitter' : '未登录', style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(
                  _isAuthenticated
                      ? 'Auth Token: ${_authToken!.substring(0, 8)}...'
                      : '需要登录才能下载图片',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              const Divider(height: 1, indent: 56, color: Colors.white10),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: _isAuthenticated
                    ? ElevatedButton(
                        onPressed: _clearAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.w600)),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginWebView()),
                          );
                          if (result == true) {
                            _checkAuthStatus();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('登录 Twitter', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('关于 & 帮助'),
          _buildCard(
            children: [
              ListTile(
                leading: _buildIcon(Icons.info_outline, Colors.blue),
                title: const Text('Twitter 原图下载器', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Text('v1.0.0', style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
              const Divider(height: 1, indent: 56, color: Colors.white10),
              ListTile(
                leading: _buildIcon(Icons.bug_report, Colors.orange),
                title: const Text('查看分享扩展日志', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExtensionLogPage()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56, color: Colors.white10),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('使用说明', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    SizedBox(height: 8),
                    Text(
                      '1. 在设置中登录 Twitter 账号\n'
                      '2. 在主页粘贴推文链接并解析下载\n'
                      '3. 或在推特官方客户端中，点击分享，选择本应用，即可直接通过弹窗后台下载原图。',
                      style: TextStyle(color: Colors.white54, height: 1.5, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w500,
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
