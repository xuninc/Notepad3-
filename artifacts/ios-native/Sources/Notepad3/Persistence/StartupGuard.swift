import Foundation

/// Safety net that prevents a repeated crash-on-launch when classic mode
/// renders incorrectly. Ported from the RN version's `LAYOUT_PENDING_KEY`
/// mechanism.
///
/// Flow:
///  - At scene-connect time, `verifyLayoutModeAtStartup(_:)` checks if the
///    previous boot was going into classic mode and never got far enough
///    to clear its "surviving render" flag. If that flag is still set when
///    we launch again, treat it as a crash and force the preference back
///    to `.mobile` before the UI is built.
///  - Once the editor has survived the first render (~1.5s after
///    `viewDidAppear`), call `markLayoutRenderSurvived()` to clear the flag.
enum StartupGuard {
    private static let pendingClassicKey = "notepad3pp.layoutMode.pendingClassic"
    private static let renderGrace: TimeInterval = 1.5

    /// Inspect the pending-render flag. If it's set and the user's preference
    /// is classic, downgrade to mobile — classic mode crashed on the previous
    /// run and we don't want the app stuck in a boot loop. Otherwise, if the
    /// preference is classic, arm the flag so the NEXT boot knows we tried.
    static func verifyLayoutModeAtStartup(_ prefs: Preferences) {
        let defaults = UserDefaults.standard
        let pending = defaults.bool(forKey: pendingClassicKey)

        if prefs.layoutMode == .classic && pending {
            // Previous boot went into classic and didn't survive. Fall back.
            prefs.layoutMode = .mobile
            defaults.removeObject(forKey: pendingClassicKey)
            return
        }

        if prefs.layoutMode == .classic {
            defaults.set(true, forKey: pendingClassicKey)
        } else {
            defaults.removeObject(forKey: pendingClassicKey)
        }
    }

    /// Schedule a grace-period clear of the pending-classic flag. Call from
    /// viewDidAppear: if the UI is still up after `renderGrace` seconds we
    /// can be confident classic didn't crash this time.
    static func scheduleRenderSurvivalClear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + renderGrace) {
            UserDefaults.standard.removeObject(forKey: pendingClassicKey)
        }
    }
}
