import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class TweetMedia {
  final String mediaUrlHttps;
  final String type;
  bool selected;

  TweetMedia({
    required this.mediaUrlHttps,
    required this.type,
    this.selected = true,
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
    if (result['__typename'] == 'TweetWithVisibilityResults') {
      legacy = (result['tweet'] as Map<String, dynamic>?)?['legacy']
          as Map<String, dynamic>?;
    } else {
      legacy = result['legacy'] as Map<String, dynamic>?;
    }

    if (legacy == null) throw Exception('无法解析推文内容');

    final extendedEntities =
        legacy['extended_entities'] as Map<String, dynamic>?;
    if (extendedEntities == null) throw Exception('该推文没有媒体内容');

    final mediaList = extendedEntities['media'] as List?;
    if (mediaList == null || mediaList.isEmpty) throw Exception('未找到图片');

    return mediaList
        .where((m) => m['type'] == 'photo')
        .map((m) => TweetMedia(
              mediaUrlHttps: m['media_url_https'] as String,
              type: m['type'] as String,
            ))
        .toList();
  }

  static Future<int> downloadAndSaveImages(List<TweetMedia> mediaList) async {
    final prefs = await SharedPreferences.getInstance();
    final quality = prefs.getString('tw_download_quality') ?? 'orig';
    
    int savedCount = 0;
    for (final media in mediaList) {
      try {
        final response = await http.get(Uri.parse(media.getUrl(quality)));
        if (response.statusCode == 200) {
          final result = await ImageGallerySaver.saveImage(
            Uint8List.fromList(response.bodyBytes),
            quality: 100,
            name:
                'twitter_${DateTime.now().millisecondsSinceEpoch}_$savedCount',
          );
          if (result != null && result['isSuccess'] == true) {
            savedCount++;
          }
        }
      } catch (e) {
        debugPrint('下载图片失败: $e');
      }
    }
    return savedCount;
  }
}
