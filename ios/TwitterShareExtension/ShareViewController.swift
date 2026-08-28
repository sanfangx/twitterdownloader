import UIKit
import Social
import UniformTypeIdentifiers
import Photos

class ShareViewController: UIViewController {

    let appGroupId = "group.com.trollstore.twitterdownloader"
    let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        extractUrlAndDownload()
    }

    func extractUrlAndDownload() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.completeExtension()
            return
        }

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (item, error) in
                if let url = item as? URL {
                    self.processTwitterUrl(url.absoluteString)
                } else {
                    self.completeExtension()
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                if let text = item as? String, let url = self.extractUrl(from: text) {
                    self.processTwitterUrl(url)
                } else {
                    self.completeExtension()
                }
            }
        } else {
            self.completeExtension()
        }
    }

    func extractUrl(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first?.url?.absoluteString
    }

    func processTwitterUrl(_ urlString: String) {
        guard let tweetIdMatch = urlString.range(of: "(?<=status/)\\d+", options: .regularExpression),
              let defaults = UserDefaults(suiteName: appGroupId),
              let authToken = defaults.string(forKey: "tw_auth_token"),
              let ct0 = defaults.string(forKey: "tw_ct0") else {
            self.showToast("未找到配置或链接无效")
            self.completeExtension()
            return
        }
        
        let tweetId = String(urlString[tweetIdMatch])
        Task {
            await fetchAndDownload(tweetId: tweetId, authToken: authToken, ct0: ct0)
        }
    }

    func fetchAndDownload(tweetId: String, authToken: String, ct0: String) async {
        let queryId = "2ICDjqPd81tulZcYrtpTuQ"
        let apiUrl = "https://x.com/i/api/graphql/\(queryId)/TweetResultByRestId"
        
        var components = URLComponents(string: apiUrl)!
        let variables = ["tweetId": tweetId, "withCommunity": false, "includePromotedContent": false, "withVoice": false] as [String : Any]
        let features = ["creator_subscriptions_tweet_preview_api_enabled": true, "tweetypie_unmention_optimization_enabled": true, "responsive_web_edit_tweet_api_enabled": true, "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true, "view_counts_everywhere_api_enabled": true, "longform_notetweets_consumption_enabled": true, "responsive_web_twitter_article_tweet_consumption_enabled": false, "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true, "interactive_text_enabled": true, "responsive_web_text_conversations_enabled": false, "longform_notetweets_rich_text_read_enabled": true, "longform_notetweets_inline_media_enabled": true, "responsive_web_enhance_cards_enabled": false]
        
        let variablesData = try! JSONSerialization.data(withJSONObject: variables)
        let featuresData = try! JSONSerialization.data(withJSONObject: features)
        
        components.queryItems = [
            URLQueryItem(name: "variables", value: String(data: variablesData, encoding: .utf8)),
            URLQueryItem(name: "features", value: String(data: featuresData, encoding: .utf8))
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "authorization")
        request.setValue("auth_token=\(authToken); ct0=\(ct0);", forHTTPHeaderField: "cookie")
        request.setValue(ct0, forHTTPHeaderField: "x-csrf-token")
        request.setValue("yes", forHTTPHeaderField: "x-twitter-active-user")
        request.setValue("OAuth2Session", forHTTPHeaderField: "x-twitter-auth-type")
        request.setValue("https://x.com", forHTTPHeaderField: "origin")
        request.setValue("https://x.com/", forHTTPHeaderField: "referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "user-agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let tweetResult = dataObj["tweetResult"] as? [String: Any],
               let result = tweetResult["result"] as? [String: Any] {
               
                let legacy = (result["__typename"] as? String == "TweetWithVisibilityResults" ? (result["tweet"] as? [String: Any])?["legacy"] : result["legacy"]) as? [String: Any]
                
                if let extended = legacy?["extended_entities"] as? [String: Any],
                   let medias = extended["media"] as? [[String: Any]] {
                    
                    var savedCount = 0
                    for media in medias {
                        if media["type"] as? String == "photo", let mediaUrl = media["media_url_https"] as? String {
                            let origUrlStr = mediaUrl.contains("?format=") ? mediaUrl.replacingOccurrences(of: "name=[^&]+", with: "name=orig", options: .regularExpression) : mediaUrl + ":orig"
                            
                            if let imgUrl = URL(string: origUrlStr) {
                                let (imgData, _) = try await URLSession.shared.data(from: imgUrl)
                                if let image = UIImage(data: imgData) {
                                    try await PHPhotoLibrary.shared().performChanges {
                                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                                    }
                                    savedCount += 1
                                }
                            }
                        }
                    }
                    if savedCount > 0 {
                        showToast("✅ 成功下载 \(savedCount) 张原图")
                    } else {
                        showToast("未找到图片")
                    }
                }
            } else {
                showToast("解析推文失败或 Cookie 过期")
            }
        } catch {
            showToast("网络请求失败")
        }
        
        completeExtension()
    }

    func showToast(_ message: String) {
        print(message)
    }

    func completeExtension() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
