import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'twitter_service.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final TextEditingController _urlController = TextEditingController();
  List<TweetMedia> _parsedMedia = [];
  bool _isParsing = false;
  bool _isDownloading = false;
  String _statusMessage = '';

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!;
      });
    } else {
      setState(() => _statusMessage = '剪贴板为空');
    }
  }

  Future<void> _parseUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _statusMessage = '请输入或粘贴推特链接');
      return;
    }

    final tweetId = TwitterService.extractTweetId(url);
    if (tweetId == null) {
      setState(() => _statusMessage = '无法识别推特链接');
      return;
    }

    if (!await TwitterService.isAuthenticated()) {
      setState(() => _statusMessage = '未登录，请先在设置页面登录 Twitter');
      return;
    }

    setState(() {
      _isParsing = true;
      _statusMessage = '正在解析推文...';
      _parsedMedia = [];
    });

    try {
      final media = await TwitterService.fetchTweetMedia(tweetId);
      setState(() {
        _parsedMedia = media;
        _isParsing = false;
        _statusMessage = '找到 ${media.length} 张图片，请选择后点击下载';
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _statusMessage = '解析失败: $e';
      });
    }
  }

  Future<void> _downloadSelected() async {
    final selected = _parsedMedia.where((m) => m.selected).toList();
    if (selected.isEmpty) {
      setState(() => _statusMessage = '请至少选择一张图片');
      return;
    }

    setState(() {
      _isDownloading = true;
      _statusMessage = '正在下载 ${selected.length} 张原图...';
    });

    try {
      final count = await TwitterService.downloadAndSaveImages(selected);
      setState(() {
        _isDownloading = false;
        _statusMessage = '✅ 成功保存 $count 张原图到相册';
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = '下载失败: $e';
      });
    }
  }

  Future<void> _pasteAndDownload() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) {
      setState(() => _statusMessage = '剪贴板为空');
      return;
    }

    final url = data.text!.trim();
    setState(() {
      _urlController.text = url;
    });

    final tweetId = TwitterService.extractTweetId(url);
    if (tweetId == null) {
      setState(() => _statusMessage = '剪贴板内容不是有效的推特链接');
      return;
    }

    if (!await TwitterService.isAuthenticated()) {
      setState(() => _statusMessage = '未登录，请先在设置页面登录 Twitter');
      return;
    }

    setState(() {
      _isDownloading = true;
      _parsedMedia = [];
      _statusMessage = '正在解析并下载...';
    });

    try {
      final media = await TwitterService.fetchTweetMedia(tweetId);
      if (media.isEmpty) {
        setState(() {
          _isDownloading = false;
          _statusMessage = '该推文没有图片';
        });
        return;
      }
      final count = await TwitterService.downloadAndSaveImages(media);
      setState(() {
        _isDownloading = false;
        _statusMessage = '✅ 成功保存 $count 张原图到相册';
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = '下载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _parsedMedia.where((m) => m.selected).length;
    final bool busy = _isParsing || _isDownloading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Twitter 原图下载'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL text field
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: '输入或粘贴推特链接',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _urlController.clear();
                            _parsedMedia = [];
                            _statusMessage = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Paste + Parse buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: const Text('粘贴'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : _parseUrl,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('解析'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Paste & Download button
            ElevatedButton.icon(
              onPressed: busy ? null : _pasteAndDownload,
              icon: const Icon(Icons.file_download, size: 18),
              label: const Text('粘贴并下载'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.blue.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 12),

            // Status bar
            if (_statusMessage.isNotEmpty || busy)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.startsWith('✅')
                              ? Colors.greenAccent
                              : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Image grid + Download button
            if (_parsedMedia.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _parsedMedia.length,
                        itemBuilder: (context, index) {
                          final media = _parsedMedia[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                media.selected = !media.selected;
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    media.mediumUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: const Color(0xFF1E1E1E),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stack) {
                                      return Container(
                                        color: const Color(0xFF1E1E1E),
                                        child: const Center(
                                          child: Icon(Icons.broken_image,
                                              color: Colors.white38),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Dim overlay when deselected
                                if (!media.selected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                // Selection indicator
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: media.selected
                                          ? Colors.blue
                                          : Colors.black54,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: media.selected
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: (_isDownloading || selectedCount == 0)
                          ? null
                          : _downloadSelected,
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(
                          '下载选中 ($selectedCount/${_parsedMedia.length})'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.green.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
