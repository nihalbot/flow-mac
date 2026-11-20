import Cocoa
import Combine

public class DistractionBlocker: ObservableObject {
    public static let shared = DistractionBlocker()
    
    private var workspaceNotificationCancellable: AnyCancellable?
    private var timerCancellable: AnyCancellable?
    private var isMonitoring: Bool = false
    
    @Published public var blockedAppDetected: String? = nil
    @Published public var blockedSiteDetected: String? = nil
    
    public init() {}
    
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Monitor frontmost app changes (event-driven, 0% CPU)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppSwitch(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Only poll for websites if website blocking is actually enabled
        if AppSettings.shared.blockWebsitesEnabled {
            timerCancellable = Timer.publish(every: 4.0, tolerance: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.checkBrowsersForBlockedWebsites()
                }
        }
    }
    
    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        timerCancellable?.cancel()
        timerCancellable = nil
        blockedAppDetected = nil
        blockedSiteDetected = nil
    }
    
    @objc private func handleAppSwitch(_ notification: Notification) {
        let settings = AppSettings.shared
        guard settings.blockAppsEnabled else { return }
        
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = app.localizedName else { return }
        
        let blocked = settings.blockedApps.map { $0.lowercased() }
        let currentName = appName.lowercased()
        
        if blocked.contains(where: { currentName.contains($0) || $0.contains(currentName) }) {
            // App is blocked! Hide it or minimize it, and notify.
            DispatchQueue.main.async { [weak self] in
                self?.blockedAppDetected = appName
                app.hide()
                
                // Show notification
                NotificationManager.shared.showBlockedNotification(title: "Stay in Flow", message: "\(appName) is blocked during your focus session.")
                
                // Auto-clear banner after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if self?.blockedAppDetected == appName {
                        self?.blockedAppDetected = nil
                    }
                }
            }
        }
    }
    
    public func checkBrowsersForBlockedWebsites() {
        let settings = AppSettings.shared
        guard settings.blockWebsitesEnabled else { return }
        
        // Inspect frontmost app; if it's Safari or Chrome, check current URL via AppleScript
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontApp.localizedName?.lowercased() else { return }
        
        if appName.contains("safari") {
            checkSafariURL()
        } else if appName.contains("chrome") || appName.contains("brave") || appName.contains("edge") || appName.contains("arc") {
            checkChromiumURL(appName: frontApp.localizedName ?? "Google Chrome")
        }
    }
    
    private func checkSafariURL() {
        let scriptSource = """
        tell application "Safari"
            if (count of windows) > 0 then
                set currentURL to URL of current tab of front window
                return currentURL
            end if
        end tell
        return ""
        """
        evaluateURLScript(scriptSource: scriptSource, browser: "Safari") { [weak self] urlString in
            self?.evaluateAndBlock(urlString: urlString, browser: "Safari")
        }
    }
    
    private func checkChromiumURL(appName: String) {
        let scriptSource = """
        tell application "\(appName)"
            if (count of windows) > 0 then
                set currentURL to URL of active tab of front window
                return currentURL
            end if
        end tell
        return ""
        """
        evaluateURLScript(scriptSource: scriptSource, browser: appName) { [weak self] urlString in
            self?.evaluateAndBlock(urlString: urlString, browser: appName)
        }
    }
    
    private func evaluateURLScript(scriptSource: String, browser: String, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                let descriptor = script.executeAndReturnError(&error)
                let result = descriptor.stringValue ?? ""
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
    
    private func evaluateAndBlock(urlString: String, browser: String) {
        let settings = AppSettings.shared
        guard !urlString.isEmpty else { return }
        
        for blocked in settings.blockedWebsites {
            let lowerBlocked = blocked.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !lowerBlocked.isEmpty && urlString.lowercased().contains(lowerBlocked) {
                // Blocked website detected!
                self.blockedSiteDetected = lowerBlocked
                
                // Redirect tab away from distraction
                let redirectScript = """
                tell application "\(browser)"
                    set URL of active tab of front window to "about:blank"
                end tell
                """
                DispatchQueue.global(qos: .userInitiated).async {
                    var error: NSDictionary?
                    if let script = NSAppleScript(source: redirectScript) {
                        script.executeAndReturnError(&error)
                    }
                }
                
                NotificationManager.shared.showBlockedNotification(
                    title: "Focus Shield Activated",
                    message: "\(lowerBlocked) is blocked during Focus mode."
                )
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    if self?.blockedSiteDetected == lowerBlocked {
                        self?.blockedSiteDetected = nil
                    }
                }
                break
            }
        }
    }
}
