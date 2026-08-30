import UIKit
import UniformTypeIdentifiers
import Photos

class ShareViewController: UIViewController {

    let appGroupId = "group.com.trollstore.twitterdownloader"
    let bearerToken = "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

    // UI Elements
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let cardView = UIView()
    private let handleBar = UIView()
    private let titleLabel = UILabel()
    private let resultIconLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let closeButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private var downloadTask: Task<Void, Never>?
    
    // Background download tracking
    private var bgSession: URLSession?
    private var pendingDownloads: Int = 0
    private var savedCount: Int = 0
    private var failedCount: Int = 0
    private var totalImages: Int = 0
    private let counterQueue = DispatchQueue(label: "com.trollstore.twitterdownloader.counter")
    
    // For retry
    private var lastTweetId: String?
    private var lastAuthToken: String?
    private var lastCt0: String?
    
    // Pan gesture tracking
    private var cardInitialY: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        animateCardIn()
        startProcess()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        self.view.backgroundColor = .clear
        
        // 1. Native dark blur background (fixes green tint)
        blurView.frame = self.view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(blurView)
        
        // Tap blur area to close
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        blurView.addGestureRecognizer(tapGesture)
        
        // Card view (bottom sheet)
        cardView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
        cardView.layer.cornerRadius = 24
        cardView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.3
        cardView.layer.shadowOffset = CGSize(width: 0, height: -4)
        cardView.layer.shadowRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(cardView)
        
        // Prevent tap-through on card
        let cardTap = UITapGestureRecognizer(target: self, action: nil)
        cardView.addGestureRecognizer(cardTap)
        
        // 3. Pan gesture for swipe-down dismiss
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        cardView.addGestureRecognizer(panGesture)
        
        // Handle bar
        handleBar.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        handleBar.layer.cornerRadius = 2.5
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(handleBar)
        
        // Title
        titleLabel.text = "原图下载"
        titleLabel.textColor = .white
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        // 4. Result icon (hidden initially, shown on success/failure)
        resultIconLabel.font = .systemFont(ofSize: 48)
        resultIconLabel.textAlignment = .center
        resultIconLabel.isHidden = true
        resultIconLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(resultIconLabel)
        
        // Activity indicator (shown during loading)
        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        // 2. Progress bar
        progressBar.progressTintColor = .systemBlue
        progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressBar.progress = 0
        progressBar.isHidden = true
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(progressBar)
        
        // Status label
        statusLabel.text = "正在读取分享内容..."
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        statusLabel.font = .systemFont(ofSize: 15)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusLabel)
        
        // Close button
        closeButton.setTitle("取消", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        closeButton.layer.cornerRadius = 14
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        cardView.addSubview(closeButton)
        
        // 4. Retry button (hidden by default, shown on failure)
        retryButton.setTitle("重试", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.backgroundColor = .systemOrange
        retryButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        retryButton.layer.cornerRadius = 14
        retryButton.isHidden = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        cardView.addSubview(retryButton)
        
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            
            handleBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            resultIconLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            resultIconLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            resultIconLabel.heightAnchor.constraint(equalToConstant: 56),
            
            activityIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 28),
            activityIndicator.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            
            progressBar.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            progressBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            progressBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            
            retryButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            retryButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            retryButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            retryButton.heightAnchor.constraint(equalToConstant: 50),
            
            closeButton.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 10),
            closeButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            closeButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Animations
    private func animateCardIn() {
        cardView.transform = CGAffineTransform(translationX: 0, y: 400)
        blurView.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5) {
            self.cardView.transform = .identity
            self.blurView.alpha = 1
        }
    }
    
    private func animateCardOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn, animations: {
            self.cardView.transform = CGAffineTransform(translationX: 0, y: self.cardView.bounds.height)
            self.blurView.alpha = 0
        }) { _ in
            completion()
        }
    }
    
    // MARK: - 3. Pan Gesture (swipe down to dismiss)
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.view)
        let velocity = gesture.velocity(in: self.view)
        
        switch gesture.state {
        case .began:
            cardInitialY = cardView.transform.ty
        case .changed:
            // Only allow downward drag
            let newY = cardInitialY + translation.y
            if newY >= 0 {
                cardView.transform = CGAffineTransform(translationX: 0, y: newY)
                // Fade blur proportionally
                let progress = min(newY / 300.0, 1.0)
                blurView.alpha = 1.0 - progress * 0.5
            }
        case .ended, .cancelled:
            // If dragged more than 120pt down or velocity is fast enough, dismiss
            if translation.y > 120 || velocity.y > 800 {
                dismissExtension()
            } else {
                // Snap back
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                    self.cardView.transform = .identity
                    self.blurView.alpha = 1
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Actions
    @objc private func closeTapped() {
        dismissExtension()
    }
    
    @objc private func retryTapped() {
        guard let tweetId = lastTweetId, let authToken = lastAuthToken, let ct0 = lastCt0 else { return }
        
        // Reset UI to loading state
        DispatchQueue.main.async {
            self.resultIconLabel.isHidden = true
            self.activityIndicator.isHidden = false
            self.activityIndicator.startAnimating()
            self.progressBar.progress = 0
            self.progressBar.isHidden = true
            self.retryButton.isHidden = true
            self.closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            self.closeButton.setTitle("取消", for: .normal)
        }
        
        updateStatus("正在重试...")
        
        downloadTask = Task {
            await fetchTweetAndDownloadImages(tweetId: tweetId, authToken: authToken, ct0: ct0)
        }
    }
    
    private func dismissExtension() {
        downloadTask?.cancel()
        bgSession?.invalidateAndCancel()
        animateCardOut {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - Status Updates
    private func updateStatus(_ message: String, isFinished: Bool = false) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
        }
    }
    
    private func showSuccess(saved: Int, total: Int) {
        DispatchQueue.main.async {
            // 4. Visual success feedback
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.progressBar.isHidden = true
            
            self.resultIconLabel.text = "✅"
            self.resultIconLabel.isHidden = false
            self.resultIconLabel.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                self.resultIconLabel.transform = .identity
            }
            
            self.statusLabel.text = "成功保存 \(saved)/\(total) 张原图到相册"
            self.statusLabel.textColor = .white
            
            self.retryButton.isHidden = true
            self.closeButton.backgroundColor = .systemGreen
            self.closeButton.setTitle("完成", for: .normal)
        }
        
        // Auto-close after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.bgSession?.finishTasksAndInvalidate()
            self.animateCardOut {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }
    
    private func showFailure(message: String, canRetry: Bool) {
        DispatchQueue.main.async {
            // 4. Visual failure feedback
            self.activityIndicator.stopAnimating()
            self.activityIndicator.isHidden = true
            self.progressBar.isHidden = true
            
            self.resultIconLabel.text = "❌"
            self.resultIconLabel.isHidden = false
            self.resultIconLabel.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                self.resultIconLabel.transform = .identity
            }
            
            self.statusLabel.text = message
            self.statusLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
            
            self.retryButton.isHidden = !canRetry
            self.closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            self.closeButton.setTitle("关闭", for: .normal)
        }
    }
    
    private func updateProgress(_ progress: Float) {
        DispatchQueue.main.async {
            self.progressBar.isHidden = false
            self.progressBar.setProgress(progress, animated: true)
        }
    }
    
    // MARK: - Process Flow
    private func startProcess() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showFailure(message: "未找到分享内容", canRetry: false)
            return
        }

        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                if let url = item as? URL {
                    self?.processTwitterUrl(url.absoluteString)
                } else {
                    self?.showFailure(message: "分享的不是有效链接", canRetry: false)
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                if let text = item as? String, let url = self?.extractUrl(from: text) {
                    self?.processTwitterUrl(url)
                } else {
                    self?.showFailure(message: "未在文本中提取到链接", canRetry: false)
                }
            }
        } else {
            showFailure(message: "不支持的分享类型", canRetry: false)
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
            showFailure(message: "未找到账号配置或链接无效\n请先在主 App 登录", canRetry: false)
            return
        }
        
        let tweetId = String(urlString[tweetIdMatch])
        
        // Save for retry
        lastTweetId = tweetId
        lastAuthToken = authToken
        lastCt0 = ct0
        
        updateStatus("正在请求推文数据...")
        
        downloadTask = Task {
            await fetchTweetAndDownloadImages(tweetId: tweetId, authToken: authToken, ct0: ct0)
        }
    }

    // MARK: - Fetch tweet data (small JSON, uses standard URLSession)
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
                showFailure(message: "API 请求失败: HTTP \(httpResponse.statusCode)", canRetry: true)
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
                        showFailure(message: "未在这条推文中找到图片", canRetry: false)
                        return
                    }
                    
                    startBackgroundDownloads(urls: imageUrls)
                    
                } else {
                    showFailure(message: "推文中没有媒体内容", canRetry: false)
                }
            } else {
                showFailure(message: "解析推文失败\n可能由于 Cookie 过期或权限不足", canRetry: true)
            }
        } catch {
            if Task.isCancelled { return }
            showFailure(message: "请求推文数据失败\n\(error.localizedDescription)", canRetry: true)
        }
    }
    
    // MARK: - Background URLSession for image downloads
    private func startBackgroundDownloads(urls: [URL]) {
        counterQueue.sync {
            totalImages = urls.count
            pendingDownloads = urls.count
            savedCount = 0
            failedCount = 0
        }
        
        updateStatus("正在下载 \(urls.count) 张原图...")
        updateProgress(0)
        
        let sessionId = "com.trollstore.twitterdownloader.bg.\(UUID().uuidString)"
        let config = URLSessionConfiguration.background(withIdentifier: sessionId)
        config.sharedContainerIdentifier = appGroupId
        config.sessionSendsLaunchEvents = false
        config.isDiscretionary = false
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
        var currentPending = 0
        var currentSaved = 0
        var currentFailed = 0
        var currentTotal = 0
        
        counterQueue.sync {
            pendingDownloads -= 1
            currentPending = pendingDownloads
            currentSaved = savedCount
            currentFailed = failedCount
            currentTotal = totalImages
        }
        
        let done = currentTotal - currentPending
        let overallProgress = Float(done) / Float(max(currentTotal, 1))
        updateProgress(overallProgress)
        updateStatus("已完成 \(done)/\(currentTotal)，成功 \(currentSaved) 张")
        
        if currentPending <= 0 {
            if currentSaved > 0 {
                showSuccess(saved: currentSaved, total: currentTotal)
            } else {
                showFailure(message: "下载完成，但未能保存任何图片到相册\n失败 \(currentFailed) 张", canRetry: true)
                bgSession?.finishTasksAndInvalidate()
            }
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension ShareViewController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
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
                self?.counterQueue.sync {
                    self?.failedCount += 1
                }
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        checkAllDownloadsComplete()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            
            print("Download failed: \(error.localizedDescription)")
            counterQueue.sync {
                failedCount += 1
            }
            checkAllDownloadsComplete()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            var currentPending = 0
            var currentTotal = 0
            counterQueue.sync {
                currentPending = pendingDownloads
                currentTotal = totalImages
            }
            
            let fileProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            let completedFiles = currentTotal - currentPending
            let overallProgress = (Float(completedFiles) + fileProgress) / Float(max(currentTotal, 1))
            
            let done = completedFiles + 1
            let pct = Int(fileProgress * 100)
            updateProgress(overallProgress)
            updateStatus("正在下载 (\(done)/\(currentTotal))... \(pct)%")
        }
    }
}
