import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Crash-loop safety net: if the previous run got as far as choosing
        // classic mode but didn't survive the first render, fall back to
        // mobile BEFORE we build the UI. See StartupGuard.
        StartupGuard.verifyLayoutModeAtStartup(Preferences.shared)

        let window = UIWindow(windowScene: windowScene)
        let store = NotesStore.shared
        let editor = EditorViewController(store: store)
        let nav = UINavigationController(rootViewController: editor)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window
    }
}
