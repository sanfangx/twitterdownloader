import UIKit
import UniformTypeIdentifiers
import Photos

class ShareViewController: UIViewController {

    let appGroupId = "group.com.trollstore.twitterdownloader"
    let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    // UI Elements
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let closeButton = UIButton(type: .system)
    private var downloadTask: Task<Void, Never>?
    
    // Background download tracking
    private var bgSession: URLSession?
    private var pendingDownloads: Int = 0
    private var savedCount: Int = 0
    private var totalImages: Int = 0
    private let maxRetries = 2
    private let counterQueue = DispatchQueue(label: "com.trollstore.twitterdownloader.counter")

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startProcess()
    }
    
    private func setupUI() {
        // Semi-transparent dimming background
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        // Tap outside to close
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        self.view.addGestureRecognizer(tapGesture)
        
        // Half-screen bottom sheet
        cardView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        cardView.layer.cornerRadius = 24
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(cardView)
        
        let cardTap = UITapGestureRecognizer(target: self, action: nil)
        cardView.addGestureRecognizer(cardTap)
        
        // Handle bar at the top of the card
        let handleBar = UIView()
        handleBar.backgroundColor = .darkGray
        handleBar.layer.cornerRadius = 3
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(handleBar)
        
        titleLabel.text = "原图下载"
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        statusLabel.text = "正在读取分享内容..."
        statusLabel.textColor = .lightGray
        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusLabel)
        
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        closeButton.setTitle("取消", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        closeButton.layer.cornerRadius = 12
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        cardView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
            
            handleBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            handleBar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 6),
            
            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            activityIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            
            closeButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 40),
            closeButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc private func closeTapped() {
        downloadTask?.cancel()
        bgSession?.invalidateAndCancel()
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func updateStatus(_ message: String, isFinished: Bool = false) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
            if isFinished {
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                self.closeButton.backgroundColor = .systemBlue
                self.closeButton.setTitle("完成并关闭", for: .normal)
            }
        }
    }
    
    private func startProcess() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            self.updateStatus("未找到分享内容", isFinished: true)
            return
        }

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                if let url = item as? URL {
                    self?.processTwitterUrl(url.absoluteString)
                } else {
                    self?.updateStatus("分享的不是有效链接", isFinished: true)
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                if let text = item as? String, let url = self?.extractUrl(from: text) {
                    self?.processTwitterUrl(url)
                } else {
                    self?.updateStatus("未在文本中提取到链接", isFinished: true)
                }
            }
        } else {
            self.updateStatus("不支持的分享类型", isFinished: true)
        }
    }

    private func extractUrl(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches?.first?.url?.absoluteString
    }

    private func processTwitterUrl(_ urlString: String) {
        guard let tweetIdMatch = urlString.range(of: "(?<=status/)\\d+", options: .regularExpression),
              let defaults = UserDefaults(suiteName: appGroupId),
              let authToken = defaults.string(forKey: "tw_auth_token"),
              let ct0 = defaults.string(forKey: "tw_ct0") else {
            self.updateStatus("未找到账号配置或链接无效\n请先在主 App 登录", isFinished: true)
            return
        }
        
        let tweetId = String(urlString[tweetIdMatch])
        updateStatus("正在请求推文数据...")
        
        downloadTask = Task {
            await fetchTweetAndDownloadImages(tweetId: tweetId, authToken: authToken, ct0: ct0)
        }
    }

    // MARK: - Fetch tweet data (small JSON, uses standard URLSession — this is fine)
    private func fetchTweetAndDownloadImages(tweetId: String, authToken: String, ct0: String) async {
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
        request.timeoutInterval = 30
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "authorization")
        request.setValue("auth_token=\(authToken); ct0=\(ct0);", forHTTPHeaderField: "cookie")
        request.setValue(ct0, forHTTPHeaderField: "x-csrf-token")
        request.setValue("yes", forHTTPHeaderField: "x-twitter-active-user")
        request.setValue("OAuth2Session", forHTTPHeaderField: "x-twitter-auth-type")
        request.setValue("https://x.com", forHTTPHeaderField: "origin")
        request.setValue("https://x.com/", forHTTPHeaderField: "referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "user-agent")
        
        do {
            if Task.isCancelled { return }
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                updateStatus("API 请求失败: HTTP \(httpResponse.statusCode)", isFinished: true)
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let tweetResult = dataObj["tweetResult"] as? [String: Any],
               let result = tweetResult["result"] as? [String: Any] {
               
                let legacy = (result["__typename"] as? String == "TweetWithVisibilityResults" ? (result["tweet"] as? [String: Any])?["legacy"] : result["legacy"]) as? [String: Any]
                
                if let extended = legacy?["extended_entities"] as? [String: Any],
                   let medias = extended["media"] as? [[String: Any]] {
                    
                    let imageUrls = medias.compactMap { media -> URL? in
                        guard media["type"] as? String == "photo",
                              let mediaUrl = media["media_url_https"] as? String else { return nil }
                        let origUrlStr = mediaUrl.contains("?format=")
                            ? mediaUrl.replacingOccurrences(of: "name=[^&]+", with: "name=orig", options: .regularExpression)
                            : mediaUrl + ":orig"
                        return URL(string: origUrlStr)
                    }
                    
                    if imageUrls.isEmpty {
                        updateStatus("未在这条推文中找到图片", isFinished: true)
                        return
                    }
                    
                    // Use background URLSession for reliable image downloads
                    startBackgroundDownloads(urls: imageUrls)
                    
                } else {
                    updateStatus("推文中没有媒体内容", isFinished: true)
                }
            } else {
                updateStatus("解析推文失败，可能由于 Cookie 过期或权限不足", isFinished: true)
            }
        } catch {
            if Task.isCancelled { return }
            updateStatus("请求推文数据失败: \(error.localizedDescription)", isFinished: true)
        }
    }
    
    // MARK: - Background URLSession for image downloads
    private func startBackgroundDownloads(urls: [URL]) {
        totalImages = urls.count
        pendingDownloads = urls.count
        savedCount = 0
        
        updateStatus("正在下载 \(totalImages) 张原图...")
        
        // Create a background session that is managed by the system daemon (nsurlsessiond).
        // This survives extension process suspension/termination.
        let sessionId = "com.trollstore.twitterdownloader.bg.\(UUID().uuidString)"
        let config = URLSessionConfiguration.background(withIdentifier: sessionId)
        config.sharedContainerIdentifier = appGroupId
        config.sessionSendsLaunchEvents = false  // We don't need to wake the main app
        config.isDiscretionary = false            // Download immediately, don't wait for "good" conditions
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.httpMaximumConnectionsPerHost = 4
        
        bgSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        for url in urls {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "user-agent")
            let task = bgSession!.downloadTask(with: request)
            task.resume()
        }
    }
    
    private func checkAllDownloadsComplete() {
        counterQueue.sync {
            pendingDownloads -= 1
            
            let done = totalImages - pendingDownloads
            updateStatus("已完成 \(done)/\(totalImages)，成功 \(savedCount) 张")
            
            if pendingDownloads <= 0 {
                if savedCount > 0 {
                    updateStatus("✅ 成功保存 \(savedCount)/\(totalImages) 张原图到相册", isFinished: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.bgSession?.finishTasksAndInvalidate()
                        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                } else {
                    updateStatus("下载完成，但未能保存任何图片到相册", isFinished: true)
                    bgSession?.finishTasksAndInvalidate()
                }
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension ShareViewController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The system provides a temporary file. We must use it before this method returns.
        // Save directly to Photo Library from the temp file URL (zero memory copy).
        let semaphore = DispatchSemaphore(value: 0)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: location)
        }) { [weak self] success, error in
            if success {
                self?.counterQueue.sync {
                    self?.savedCount += 1
                }
            } else {
                print("Photo save error: \(error?.localizedDescription ?? "unknown")")
            }
            semaphore.signal()
        }
        
        // Wait for photo library to finish — the temp file at `location` is deleted
        // after this delegate method returns, so we must block until the save completes.
        semaphore.wait()
        
        checkAllDownloadsComplete()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            // Don't count cancellations (user tapped close)
            if nsError.code == NSURLErrorCancelled {
                return
            }
            print("Download failed: \(error.localizedDescription)")
            checkAllDownloadsComplete()
        }
        // If error is nil, didFinishDownloadingTo was already called — do nothing here.
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // Optional: show per-file progress
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            let done = totalImages - pendingDownloads
            let pct = Int(progress * 100)
            updateStatus("正在下载 (\(done + 1)/\(totalImages))... \(pct)%")
        }
    }
}
