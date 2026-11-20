import SwiftUI
import Combine

public enum MenuBarDisplayMode: String, CaseIterable, Codable, Identifiable {
    case iconAndTime = "Icon & Time"
    case timeOnly = "Time Only"
    case iconOnly = "Icon Only"
    
    public var id: String { rawValue }
}

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()
    
    // Timer intervals in minutes
    @AppStorage("focusDurationMinutes") public var focusDurationMinutes: Int = 25
    @AppStorage("shortBreakDurationMinutes") public var shortBreakDurationMinutes: Int = 5
    @AppStorage("longBreakDurationMinutes") public var longBreakDurationMinutes: Int = 15
    @AppStorage("longBreakInterval") public var longBreakInterval: Int = 4
    
    // Auto-flow automation
    @AppStorage("autoStartBreaks") public var autoStartBreaks: Bool = false
    @AppStorage("autoStartFocus") public var autoStartFocus: Bool = false
    
    // Pro Features
    @AppStorage("commitmentMode") public var commitmentMode: Bool = false
    @AppStorage("fullscreenBreaks") public var fullscreenBreaks: Bool = true
    @AppStorage("showDockIcon") public var showDockIcon: Bool = false
    @AppStorage("menuBarDisplayModeRaw") public var menuBarDisplayModeRaw: String = MenuBarDisplayMode.iconAndTime.rawValue
    
    // Audio & Ambient
    @AppStorage("soundAlertsEnabled") public var soundAlertsEnabled: Bool = true
    @AppStorage("focusSoundRaw") public var focusSoundRaw: String = AlertSound.bell.rawValue
    @AppStorage("breakSoundRaw") public var breakSoundRaw: String = AlertSound.marimba.rawValue
    @AppStorage("soundVolume") public var soundVolume: Double = 0.75
    
    @AppStorage("ambientSoundRaw") public var ambientSoundRaw: String = AmbientSound.none.rawValue
    @AppStorage("ambientVolume") public var ambientVolume: Double = 0.35
    
    // Blocker
    @AppStorage("blockAppsEnabled") public var blockAppsEnabled: Bool = false
    @AppStorage("blockWebsitesEnabled") public var blockWebsitesEnabled: Bool = false
    
    // Apple Calendar Sync
    @AppStorage("calendarSyncEnabled") public var calendarSyncEnabled: Bool = false
    @AppStorage("calendarName") public var calendarName: String = "Flow"
    
    // Free Cloud Sync
    @AppStorage("iCloudSyncEnabled") public var iCloudSyncEnabled: Bool = true
    @AppStorage("customCloudSyncEnabled") public var customCloudSyncEnabled: Bool = false
    
    // Daily target & Streaks
    @AppStorage("dailyTargetSessions") public var dailyTargetSessions: Int = 8
    @AppStorage("allTimeBestStreak") public var allTimeBestStreak: Int = 0
    
    // Custom sessions / categories stored as JSON
    @Published public var categories: [SessionCategory] = SessionCategory.defaultCategories
    @Published public var blockedApps: [String] = ["Slack", "Discord", "Messages", "Twitter", "Steam", "Spotify", "Telegram"]
    @Published public var blockedWebsites: [String] = [
        "twitter.com",
        "x.com",
        "reddit.com",
        "youtube.com",
        "instagram.com",
        "facebook.com",
        "tiktok.com",
        "news.ycombinator.com"
    ]
    
    public var menuBarDisplayMode: MenuBarDisplayMode {
        get { MenuBarDisplayMode(rawValue: menuBarDisplayModeRaw) ?? .iconAndTime }
        set { menuBarDisplayModeRaw = newValue.rawValue }
    }
    
    public var focusSound: AlertSound {
        get { AlertSound(rawValue: focusSoundRaw) ?? .bell }
        set { focusSoundRaw = newValue.rawValue }
    }
    
    public var breakSound: AlertSound {
        get { AlertSound(rawValue: breakSoundRaw) ?? .marimba }
        set { breakSoundRaw = newValue.rawValue }
    }
    
    public var ambientSound: AmbientSound {
        get { AmbientSound(rawValue: ambientSoundRaw) ?? .none }
        set { ambientSoundRaw = newValue.rawValue }
    }
    
    public init() {
        loadCustomLists()
    }
    
    public func loadCustomLists() {
        if let data = UserDefaults.standard.data(forKey: "savedCategories"),
           let list = try? JSONDecoder().decode([SessionCategory].self, from: data) {
            self.categories = list
        }
        
        if let apps = UserDefaults.standard.stringArray(forKey: "savedBlockedApps") {
            self.blockedApps = apps
        }
        
        if let sites = UserDefaults.standard.stringArray(forKey: "savedBlockedWebsites") {
            self.blockedWebsites = sites
        }
    }
    
    public func saveCategories() {
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: "savedCategories")
        }
    }
    
    public func saveBlockedApps() {
        UserDefaults.standard.set(blockedApps, forKey: "savedBlockedApps")
    }
    
    public func saveBlockedWebsites() {
        UserDefaults.standard.set(blockedWebsites, forKey: "savedBlockedWebsites")
    }
    
    public func addCategory(name: String, colorHex: String, icon: String) {
        let newCat = SessionCategory(name: name, colorHex: colorHex, icon: icon)
        categories.append(newCat)
        saveCategories()
    }
    
    public func removeCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        saveCategories()
    }
    
    public func addBlockedApp(_ app: String) {
        let trimmed = app.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !blockedApps.contains(trimmed) {
            blockedApps.append(trimmed)
            saveBlockedApps()
        }
    }
    
    public func removeBlockedApp(at index: Int) {
        guard index >= 0 && index < blockedApps.count else { return }
        blockedApps.remove(at: index)
        saveBlockedApps()
    }
    
    public func addBlockedWebsite(_ site: String) {
        let trimmed = site.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty && !blockedWebsites.contains(trimmed) {
            blockedWebsites.append(trimmed)
            saveBlockedWebsites()
        }
    }
    
    public func removeBlockedWebsite(at index: Int) {
        guard index >= 0 && index < blockedWebsites.count else { return }
        blockedWebsites.remove(at: index)
        saveBlockedWebsites()
    }
}
