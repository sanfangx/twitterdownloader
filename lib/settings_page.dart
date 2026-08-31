import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preference_app_group/shared_preference_app_group.dart';
import 'extension_log_page.dart';

const String appGroupId = 'group.com.trollstore.twitterdownloader';

// =======================
// Main Settings Page
// =======================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
          _buildCard([
            _buildListItem(
              context,
              icon: Icons.person,
              iconColor: Colors.blue,
              title: '账号设置',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AccountSettingsPage())),
            ),
            const Divider(height: 1, indent: 56, color: Colors.white10),
            _buildListItem(
              context,
              icon: Icons.download,
              iconColor: Colors.green,
              title: '下载设置',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DownloadSettingsPage())),
            ),
            const Divider(height: 1, indent: 56, color: Colors.white10),
            _buildListItem(
              context,
              icon: Icons.info_outline,
              iconColor: Colors.orange,
              title: '关于 & 帮助',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage())),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
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

  Widget _buildListItem(BuildContext context,
      {required IconData icon,
      required Color iconColor,
      required String title,
      VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: iconColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

// =======================
// Account Settings Page
// =======================
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
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
    final token = prefs.getString('tw_auth_token');
    final ct0 = prefs.getString('tw_ct0');
    setState(() {
      _authToken = token;
      _ct0 = ct0;
      _isAuthenticated = token != null && ct0 != null;
    });
  }

  Future<void> _clearAuth() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('退出后需要重新登录才能下载图片。'),
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
        title: const Text('账号设置'),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
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
                  title: Text(_isAuthenticated ? '已登录 Twitter' : '未登录',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('退出登录',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        )
                      : ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('登录 Twitter',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// Download Settings Page
// =======================
class DownloadSettingsPage extends StatefulWidget {
  const DownloadSettingsPage({super.key});

  @override
  State<DownloadSettingsPage> createState() => _DownloadSettingsPageState();
}

class _DownloadSettingsPageState extends State<DownloadSettingsPage> {
  String _selectedQuality = 'orig';

  @override
  void initState() {
    super.initState();
    _loadQuality();
  }

  Future<void> _loadQuality() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedQuality = prefs.getString('tw_download_quality') ?? 'orig';
    });
  }

  Future<void> _saveQuality(String quality) async {
    setState(() {
      _selectedQuality = quality;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tw_download_quality', quality);
    try {
      await SharedPreferenceAppGroup.setString('tw_download_quality', quality);
    } catch (e) {
      debugPrint('AppGroup save quality error: $e');
    }
  }

  Widget _buildQualityOption(String title, String subtitle, String value) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      trailing: _selectedQuality == value ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () => _saveQuality(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('下载设置'),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '下载清晰度',
              style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildQualityOption('原图 (Original)', '最高画质，文件最大 (推荐)', 'orig'),
                const Divider(height: 1, indent: 16, color: Colors.white10),
                _buildQualityOption('大图 (Large)', '高画质，适合日常浏览', 'large'),
                const Divider(height: 1, indent: 16, color: Colors.white10),
                _buildQualityOption('中等 (Medium)', '中等画质，节省空间', 'medium'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// About Page
// =======================
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  
  void _clearCache() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('缓存已清理')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('关于 & 帮助'),
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: _buildIcon(Icons.info_outline, Colors.blue),
                  title: const Text('Twitter 原图下载器',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Text('v1.0.0',
                      style: TextStyle(color: Colors.white54, fontSize: 15)),
                ),
                const Divider(height: 1, indent: 56, color: Colors.white10),
                ListTile(
                  leading: _buildIcon(Icons.delete_outline, Colors.redAccent),
                  title: const Text('清理图片缓存',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: _clearCache,
                ),
                const Divider(height: 1, indent: 56, color: Colors.white10),
                ListTile(
                  leading: _buildIcon(Icons.bug_report, Colors.orange),
                  title: const Text('查看分享扩展日志',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ExtensionLogPage()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56, color: Colors.white10),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('使用说明',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      SizedBox(height: 8),
                      Text(
                        '1. 在设置中登录 Twitter 账号\n'
                        '2. 在主页粘贴推文链接并解析下载\n'
                        '3. 或在推特官方客户端中，点击分享，选择本应用，即可直接通过弹窗后台下载原图。',
                        style: TextStyle(
                            color: Colors.white54, height: 1.5, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
}

// =======================
// Login WebView (Kept Same)
// =======================
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
      final gotCookies = await cookieManager.getCookies('https://twitter.com');
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
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
