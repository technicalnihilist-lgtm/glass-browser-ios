import UIKit
import WebKit

/// Native shell for the Glass Browser HTML app.
///
/// The bundled `Glass_Browser.html` is loaded unchanged, but through
/// `loadHTMLString(_:baseURL:)` with a synthetic **https** base URL rather than
/// from `file://`. Reason: WebKit treats `file://` documents as opaque origins,
/// so `localStorage` throws a SecurityError there and the browser's tabs,
/// bookmarks, history and settings would silently fail to persist. A synthetic
/// https origin gives the page a normal, secure, persistent origin, so
/// localStorage and the clipboard API behave exactly as they do in Safari.
final class BrowserViewController: UIViewController {

    /// Origin the page believes it is running on. Nothing is ever fetched from
    /// this host: the HTML is a single self-contained file with no subresources.
    private static let virtualOrigin = URL(string: "https://appassets.local/")!

    private var webView: WKWebView!
    private let backButton = UIButton(type: .system)
    private var didLoadPage = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(red: 0.043, green: 0.063, blue: 0.125, alpha: 1.0)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Pinned to the view's edges, not the safe area: the page handles the
        // notch itself through env(safe-area-inset-*).
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        configureBackButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadBundledPageIfNeeded()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    // MARK: - Page loading

    private func loadBundledPageIfNeeded() {
        guard !didLoadPage else { return }
        didLoadPage = true

        guard
            let url = Bundle.main.url(forResource: "Glass_Browser", withExtension: "html"),
            let html = try? String(contentsOf: url, encoding: .utf8)
        else {
            presentMissingPageAlert()
            return
        }
        webView.loadHTMLString(html, baseURL: Self.virtualOrigin)
    }

    private func presentMissingPageAlert() {
        let alert = UIAlertController(
            title: "Glass Browser",
            message: "Glass_Browser.html is missing from the app bundle.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Floating back button

    private func configureBackButton() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setTitle("\u{2190}", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        backButton.setTitleColor(.white, for: .normal)
        backButton.backgroundColor = UIColor(red: 0.063, green: 0.094, blue: 0.157, alpha: 0.82)
        backButton.layer.cornerRadius = 21
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.35).cgColor
        backButton.layer.shadowColor = UIColor.black.cgColor
        backButton.layer.shadowOpacity = 0.25
        backButton.layer.shadowRadius = 6
        backButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        backButton.accessibilityLabel = "Back to Glass Browser"
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(goBackToApp), for: .touchUpInside)

        view.addSubview(backButton)
        NSLayoutConstraint.activate([
            backButton.widthAnchor.constraint(equalToConstant: 42),
            backButton.heightAnchor.constraint(equalToConstant: 42),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)
        ])
    }

    @objc private func goBackToApp() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            didLoadPage = false
            loadBundledPageIfNeeded()
        }
        updateBackButton(for: webView.url)
    }

    /// Shown only while a real website is on top; the app's own UI is its own back.
    private func updateBackButton(for url: URL?) {
        let string = url?.absoluteString ?? ""
        let isAppUI = string.isEmpty
            || string == "about:blank"
            || string.hasPrefix(Self.virtualOrigin.absoluteString)

        if isAppUI {
            if !backButton.isHidden {
                UIView.animate(withDuration: 0.18) { self.backButton.alpha = 0 } completion: { _ in
                    self.backButton.isHidden = true
                }
            }
        } else if backButton.isHidden {
            backButton.isHidden = false
            backButton.alpha = 0
            UIView.animate(withDuration: 0.18) { self.backButton.alpha = 1 }
        }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        let inAppSchemes: Set<String> = ["http", "https", "file", "about", "data", "blob", "javascript"]
        if inAppSchemes.contains(scheme) {
            decisionHandler(.allow)
            return
        }

        // tel:, mailto:, sms:, maps: and friends belong to another app.
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateBackButton(for: webView.url)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updateBackButton(for: webView.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateBackButton(for: webView.url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateBackButton(for: webView.url)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateBackButton(for: webView.url)
    }
}

// MARK: - WKUIDelegate

extension BrowserViewController: WKUIDelegate {

    /// `target="_blank"` links load in the same web view instead of vanishing.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
