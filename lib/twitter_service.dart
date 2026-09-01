import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

class TweetMedia {
  final String mediaUrlHttps;
  final String type;
  final String tweetId;
  final String username;
  final int index; // 1-based index
  final int totalCount;
  final String? videoUrl; // Extracted MP4 url
  bool selected;

  TweetMedia({
    required this.mediaUrlHttps,
    required this.type,
    required this.tweetId,
    required this.username,
    required this.index,
    required this.totalCount,
    this.videoUrl,
    this.selected = false, // Requirement 1: default to not selected
  });

  String getUrl(String size) {
    if (mediaUrlHttps.contains('?format=')) {
      return mediaUrlHttps.replaceAll(RegExp(r'name=[^&]+'), 'name=$size');
    }
    final lastDot = mediaUrlHttps.lastIndexOf('.');
    if (lastDot != -1) {
      final ext = mediaUrlHttps.substring(lastDot + 1);
      final base = mediaUrlHttps.substring(0, lastDot);
      return '$base?format=$ext&name=$size';
    }
    return '$mediaUrlHttps?name=$size';
  }

  String get mediumUrl => getUrl('medium');
  String get origUrl => getUrl('orig');

  String getFilename(String rule) {
    switch (rule) {
      case 'tweet_url':
        // Option: 推文链接 (多张图片就在后面加上1，2，3，4)
        if (totalCount > 1) {
          return 'x.com_${username}_status_${tweetId}_$index';
        }
        return 'x.com_${username}_status_$tweetId';
      case 'username_tweetId':
        // Option: 用户名_推文ID_序号
        return '${username}_${tweetId}_$index';
      case 'timestamp':
      default:
        return 'twitter_${DateTime.now().millisecondsSinceEpoch}_$index';
    }
  }
}

class TwitterService {
  static const String bearerToken =
      'AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA';
  static const String queryId = '2ICDjqPd81tulZcYrtpTuQ';

  static String? extractTweetId(String input) {
    final match =
        RegExp(r'(?:twitter\.com|x\.com)/\w+/status/(\d+)').firstMatch(input);
    return match?.group(1);
  }

  static Future<Map<String, String?>> getCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'auth_token': prefs.getString('tw_auth_token'),
      'ct0': prefs.getString('tw_ct0'),
    };
  }

  static Future<bool> isAuthenticated() async {
    final creds = await getCredentials();
    return creds['auth_token'] != null && creds['ct0'] != null;
  }

  static Future<List<TweetMedia>> fetchTweetMedia(String tweetId) async {
    final creds = await getCredentials();
    final authToken = creds['auth_token'];
    final ct0 = creds['ct0'];

    if (authToken == null || ct0 == null) {
      throw Exception('未登录，请先在设置页面登录 Twitter');
    }

    final variables = jsonEncode({
      'tweetId': tweetId,
      'withCommunity': false,
      'includePromotedContent': false,
      'withVoice': false,
    });

    final features = jsonEncode({
      'creator_subscriptions_tweet_preview_api_enabled': true,
      'tweetypie_unmention_optimization_enabled': true,
      'responsive_web_edit_tweet_api_enabled': true,
      'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
      'view_counts_everywhere_api_enabled': true,
      'longform_notetweets_consumption_enabled': true,
      'responsive_web_twitter_article_tweet_consumption_enabled': false,
      'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled':
          true,
      'interactive_text_enabled': true,
      'responsive_web_text_conversations_enabled': false,
      'longform_notetweets_rich_text_read_enabled': true,
      'longform_notetweets_inline_media_enabled': true,
      'responsive_web_enhance_cards_enabled': false,
    });

    final uri = Uri.https(
        'x.com', '/i/api/graphql/$queryId/TweetResultByRestId', {
      'variables': variables,
      'features': features,
    });

    final response = await http.get(uri, headers: {
      'authorization': 'Bearer $bearerToken',
      'cookie': 'auth_token=$authToken; ct0=$ct0;',
      'x-csrf-token': ct0,
      'x-twitter-active-user': 'yes',
      'x-twitter-auth-type': 'OAuth2Session',
      'origin': 'https://x.com',
      'referer': 'https://x.com/',
      'user-agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    });

    if (response.statusCode != 200) {
      throw Exception('API 请求失败 (${response.statusCode})');
    }

    final json = jsonDecode(response.body);
    final data = json['data'];
    if (data == null) throw Exception('返回数据为空，Cookie 可能已过期');

    final tweetResult = data['tweetResult'];
    if (tweetResult == null) throw Exception('未找到推文');

    final result = tweetResult['result'];
    if (result == null) throw Exception('推文结果为空');

    Map<String, dynamic>? legacy;
    Map<String, dynamic>? core;
    if (result['__typename'] == 'TweetWithVisibilityResults') {
      final tweetObj = result['tweet'] as Map<String, dynamic>?;
      legacy = tweetObj?['legacy'] as Map<String, dynamic>?;
      core = tweetObj?['core'] as Map<String, dynamic>?;
    } else {
      legacy = result['legacy'] as Map<String, dynamic>?;
      core = result['core'] as Map<String, dynamic>?;
    }

    if (legacy == null) throw Exception('无法解析推文内容');

    final userResult = (core?['user_results'] as Map<String, dynamic>?)?['result'] as Map<String, dynamic>?;
    final userLegacy = userResult?['legacy'] as Map<String, dynamic>?;
    final username = (userLegacy?['screen_name'] ?? userResult?['screen_name'] ?? 'twitter_user') as String;

    final extendedEntities =
        legacy['extended_entities'] as Map<String, dynamic>?;
    if (extendedEntities == null) throw Exception('该推文没有媒体内容');

    final rawMediaList = extendedEntities['media'] as List?;
    if (rawMediaList == null || rawMediaList.isEmpty) throw Exception('未找到图片');

    final validMediaList = rawMediaList.where((m) {
      final t = m['type'];
      return t == 'photo' || t == 'video' || t == 'animated_gif';
    }).toList();
    
    if (validMediaList.isEmpty) throw Exception('未找到图片或视频');

    final totalCount = validMediaList.length;

    return List.generate(totalCount, (i) {
      final m = validMediaList[i];
      final type = m['type'] as String;
      String? videoUrl;

      if (type == 'video' || type == 'animated_gif') {
        final videoInfo = m['video_info'] as Map<String, dynamic>?;
        if (videoInfo != null) {
          final variants = videoInfo['variants'] as List<dynamic>?;
          if (variants != null) {
            // Find mp4 variants and sort by bitrate descending
            final mp4Variants = variants.where((v) => v['content_type'] == 'video/mp4').toList();
            mp4Variants.sort((a, b) => (b['bitrate'] ?? 0).compareTo(a['bitrate'] ?? 0));
            if (mp4Variants.isNotEmpty) {
              videoUrl = mp4Variants.first['url'] as String;
            }
          }
        }
      }

      return TweetMedia(
        mediaUrlHttps: m['media_url_https'] as String,
        type: type,
        tweetId: tweetId,
        username: username,
        index: i + 1,
        totalCount: totalCount,
        videoUrl: videoUrl,
        selected: false,
      );
    });
  }

  static Future<int> downloadAndSaveImages(List<TweetMedia> mediaList) async {
    final prefs = await SharedPreferences.getInstance();
    final quality = prefs.getString('tw_download_quality') ?? 'orig';
    final rule = prefs.getString('tw_filename_rule') ?? 'username_tweetId';

    int savedCount = 0;
    for (final media in mediaList) {
      try {
        final fileName = media.getFilename(rule);

        if (media.type == 'video' || media.type == 'animated_gif') {
          if (media.videoUrl == null) continue;
          final response = await http.get(Uri.parse(media.videoUrl!));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/$fileName.mp4');
            await file.writeAsBytes(response.bodyBytes);
            final result = await ImageGallerySaver.saveFile(file.path);
            if (result != null && result['isSuccess'] == true) {
              savedCount++;
            }
          }
        } else {
          final response = await http.get(Uri.parse(media.getUrl(quality)));
          if (response.statusCode == 200) {
            final result = await ImageGallerySaver.saveImage(
              Uint8List.fromList(response.bodyBytes),
              quality: 100,
              name: fileName,
            );
            if (result != null && result['isSuccess'] == true) {
              savedCount++;
            }
          }
        }
      } catch (e) {
        debugPrint('下载媒体失败: $e');
      }
    }
    return savedCount;
  }
}
