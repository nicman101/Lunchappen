import SwiftUI

@main
struct LunchappenApp: App {
    var body: some Scene {
        WindowGroup {
            WebContainer()
                .ignoresSafeArea()
                .background(Color("LaunchBackground"))
        }
    }
}

/// Hosts the bundled web app (Web/index.html) full screen.
struct WebContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController {
        WebViewController()
    }

    func updateUIViewController(_ controller: WebViewController, context: Context) {}
}
