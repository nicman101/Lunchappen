import CoreLocation
import MapKit
import UIKit
import WebKit

/// Runs the bundled web app and answers its requests over the `native` message handler:
/// - `location`: current position via Core Location
/// - `nearby`: restaurants, cafés and bars around a point via Apple Maps
/// - `share`: export a CSV or backup file through the share sheet
/// - `theme`: match the status bar to the theme chosen in the app
/// - `haptic`: feedback when an expense is saved
final class WebViewController: UIViewController {
    private var webView: WKWebView!
    private let locationManager = CLLocationManager()
    private var pendingLocationRequests: [String] = []

    override func loadView() {
        let contentController = WKUserContentController()
        contentController.addUserScript(WKUserScript(
            source: "window.LUNCHAPPEN_NATIVE = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        contentController.add(WeakMessageHandler(self), name: "native")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBackground")
        webView.scrollView.backgroundColor = UIColor(named: "LaunchBackground")
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsLinkPreview = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest

        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            assertionFailure("Web/index.html is missing from the app bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - Replies to the web app

    private func resolve(_ id: String, value: Any? = nil, error: String? = nil) {
        guard !id.isEmpty else { return }
        let result: [String: Any] = [
            "v": value ?? NSNull(),
            "e": error.map { $0 as Any } ?? NSNull(),
        ]
        let payload: [Any] = [id, result]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.__nativeResolve && window.__nativeResolve.apply(null, \(json));")
    }

    // MARK: - Location

    private func requestLocation(id: String) {
        pendingLocationRequests.append(id)
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finishLocationRequests(error: "denied")
        default:
            locationManager.requestLocation()
        }
    }

    private func finishLocationRequests(value: Any? = nil, error: String? = nil) {
        let ids = pendingLocationRequests
        pendingLocationRequests.removeAll()
        ids.forEach { resolve($0, value: value, error: error) }
    }

    // MARK: - Nearby restaurants (Apple Maps)

    private func findNearby(id: String, latitude: Double, longitude: Double, radius: Double) {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let request = MKLocalPointsOfInterestRequest(center: center, radius: max(radius, 50))
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .foodMarket,
        ])
        let here = CLLocation(latitude: latitude, longitude: longitude)
        MKLocalSearch(request: request).start { [weak self] response, error in
            guard let self else { return }
            let places: [[String: Any]] = (response?.mapItems ?? []).compactMap { item in
                guard let name = item.name, let location = item.placemark.location else { return nil }
                return ["name": name, "d": Int(location.distance(from: here).rounded())]
            }
            if places.isEmpty, let error, (error as? MKError)?.code != .placemarkNotFound {
                self.resolve(id, error: "net")
            } else {
                self.resolve(id, value: places)
            }
        }
    }

    // MARK: - Export

    private func share(fileName: String, text: String) {
        let safeName = fileName.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeName)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    // MARK: - Appearance

    private func applyTheme(_ mode: String) {
        let style: UIUserInterfaceStyle
        switch mode {
        case "dark": style = .dark
        case "light": style = .light
        default: style = .unspecified
        }
        view.window?.overrideUserInterfaceStyle = style
    }
}

// MARK: - WKScriptMessageHandler

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        let id = body["id"] as? String ?? ""

        switch type {
        case "location":
            requestLocation(id: id)
        case "nearby":
            guard let latitude = body["lat"] as? Double, let longitude = body["lon"] as? Double else {
                resolve(id, error: "net")
                return
            }
            findNearby(id: id, latitude: latitude, longitude: longitude, radius: body["radius"] as? Double ?? 150)
        case "share":
            share(fileName: body["name"] as? String ?? "lunchappen.txt", text: body["text"] as? String ?? "")
        case "theme":
            applyTheme(body["mode"] as? String ?? "auto")
        case "haptic":
            let kind = body["kind"] as? String
            UINotificationFeedbackGenerator().notificationOccurred(kind == "warning" ? .warning : .success)
        default:
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WebViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !pendingLocationRequests.isEmpty else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finishLocationRequests(error: "denied")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        finishLocationRequests(value: [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let denied = (error as? CLError)?.code == .denied
        finishLocationRequests(error: denied ? "denied" : "unavailable")
    }
}

// MARK: - Links and navigation

extension WebViewController: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, ["http", "https", "mailto", "tel"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // Links with target="_blank" (for example "Visa platsen på kartan") open in Safari.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

/// Avoids the retain cycle between WKUserContentController and the controller.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
