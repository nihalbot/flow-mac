import SwiftUI
import Combine

public enum SettingsTab: String, CaseIterable {
    case general = "General"
    case timer = "Timer"
    case pro = "Commitment"
    case blocker = "Distractions"
    case audio = "Sound & Audio"
    case sync = "Cloud & Sync"
}

public class PreferencesViewModel: ObservableObject {
    @Published public var selectedTab: SettingsTab = .general
    @Published public var newAppName: String = ""
    @Published public var newWebsiteName: String = ""
    @Published public var newCategoryName: String = ""
    @Published public var newCategoryColor: Color = .blue
    
    public init() {}
}

public struct PreferencesView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var soundEngine = SoundEngine.shared
    @StateObject private var vm = PreferencesViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Tab Selector
            HStack(spacing: 16) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { vm.selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: vm.selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(vm.selectedTab == tab ? .accentColor : .primary)
                            
                            Rectangle()
                                .fill(vm.selectedTab == tab ? Color.accentColor : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 20)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch vm.selectedTab {
                    case .general:
                        generalSection
                    case .timer:
                        timerSection
                    case .pro:
                        proSection
                    case .blocker:
                        blockerSection
                    case .audio:
                        audioSection
                    case .sync:
                        syncSection
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 440)
    }
    
    // MARK: - General Tab
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text("Menu Bar Appearance").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Display Format:", selection: $settings.menuBarDisplayModeRaw) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(RadioGroupPickerStyle())
                    
                    Toggle("Show Icon in macOS Dock", isOn: $settings.showDockIcon)
                        .onChange(of: settings.showDockIcon) { val in
                            NSApp.setActivationPolicy(val ? .regular : .accessory)
                        }
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Habit & Targets").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Stepper("Daily Focus Sessions Target: \(settings.dailyTargetSessions)", value: $settings.dailyTargetSessions, in: 1...20)
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Global Shortcuts").font(.headline)) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Start / Pause Session:")
                        Spacer()
                        Text("⌘ + ⌥ + Space  or  ⌘ + ⌥ + P")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Skip to Next Phase:")
                        Spacer()
                        Text("⌘ + ⌥ + S")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Reset Current Session:")
                        Spacer()
                        Text("⌘ + ⌥ + R")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - Timer Tab
    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text("Session Durations").font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    Stepper("Focus Duration: \(settings.focusDurationMinutes) minutes", value: $settings.focusDurationMinutes, in: 1...120)
                    Stepper("Short Break: \(settings.shortBreakDurationMinutes) minutes", value: $settings.shortBreakDurationMinutes, in: 1...30)
                    Stepper("Long Break: \(settings.longBreakDurationMinutes) minutes", value: $settings.longBreakDurationMinutes, in: 1...60)
                    Stepper("Rounds before Long Break: \(settings.longBreakInterval)", value: $settings.longBreakInterval, in: 1...10)
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Automation").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-start Breaks when Focus completes", isOn: $settings.autoStartBreaks)
                    Toggle("Auto-start Focus when Break completes", isOn: $settings.autoStartFocus)
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - Pro & Commitment Tab
    private var proSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text("Flow Pro Features").font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Commitment Mode (Strict Focus)", isOn: $settings.commitmentMode)
                    Text("Locks down the timer during active focus intervals to prevent premature pausing or skipping.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Toggle("Distraction-Free Fullscreen Breaks", isOn: $settings.fullscreenBreaks)
                    Text("Displays a peaceful, full-screen mindfulness view during breaks with guided breathing exercises and eye-rest prompts.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Custom Categories & Tags").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        TextField("New Category (e.g. Research)", text: $vm.newCategoryName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            guard !vm.newCategoryName.isEmpty else { return }
                            settings.addCategory(name: vm.newCategoryName, colorHex: "#4A90E2", icon: "tag.fill")
                            vm.newCategoryName = ""
                        }
                    }
                    
                    ForEach(Array(settings.categories.enumerated()), id: \.element.id) { index, cat in
                        HStack {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 8, height: 8)
                            Text(cat.name)
                                .font(.system(size: 12))
                            Spacer()
                            if settings.categories.count > 1 {
                                Button(action: {
                                    settings.removeCategory(at: IndexSet(integer: index))
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - Blocker Tab
    private var blockerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text("Application Shield").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Block Distracting Mac Apps during Focus", isOn: $settings.blockAppsEnabled)
                    
                    HStack {
                        TextField("App name to block (e.g. Slack, Discord)", text: $vm.newAppName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add App") {
                            settings.addBlockedApp(vm.newAppName)
                            vm.newAppName = ""
                        }
                    }
                    
                    ForEach(Array(settings.blockedApps.enumerated()), id: \.offset) { index, app in
                        HStack {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(app)
                                .font(.system(size: 12))
                            Spacer()
                            Button(action: { settings.removeBlockedApp(at: index) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Website Shield").font(.headline)) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Block Distracting Websites during Focus", isOn: $settings.blockWebsitesEnabled)
                    Text("Monitors Safari, Chrome, Brave, Arc, Edge and redirects away from distracting tabs.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Domain (e.g. reddit.com)", text: $vm.newWebsiteName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add Site") {
                            settings.addBlockedWebsite(vm.newWebsiteName)
                            vm.newWebsiteName = ""
                        }
                    }
                    
                    ForEach(Array(settings.blockedWebsites.enumerated()), id: \.offset) { index, site in
                        HStack {
                            Image(systemName: "globe")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Text(site)
                                .font(.system(size: 12))
                            Spacer()
                            Button(action: { settings.removeBlockedWebsite(at: index) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - Audio Tab
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(label: Text("Audio Alerts").font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Enable Sound Alerts", isOn: $settings.soundAlertsEnabled)
                    
                    HStack {
                        Picker("Focus Complete Sound:", selection: $settings.focusSoundRaw) {
                            ForEach(AlertSound.allCases) { sound in
                                Text(sound.rawValue).tag(sound.rawValue)
                            }
                        }
                        Button("Preview") {
                            soundEngine.playAlert(settings.focusSound, volume: Float(settings.soundVolume))
                        }
                    }
                    
                    HStack {
                        Picker("Break Complete Sound:", selection: $settings.breakSoundRaw) {
                            ForEach(AlertSound.allCases) { sound in
                                Text(sound.rawValue).tag(sound.rawValue)
                            }
                        }
                        Button("Preview") {
                            soundEngine.playAlert(settings.breakSound, volume: Float(settings.soundVolume))
                        }
                    }
                    
                    Slider(value: $settings.soundVolume, in: 0.1...1.0) {
                        Text("Chime Volume: \(Int(settings.soundVolume * 100))%")
                    }
                }
                .padding(10)
            }
            
            GroupBox(label: Text("Ambient Focus Sound & Metronome").font(.headline)) {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Background Audio:", selection: $settings.ambientSoundRaw) {
                        ForEach(AmbientSound.allCases) { sound in
                            Text(sound.rawValue).tag(sound.rawValue)
                        }
                    }
                    
                    Slider(value: $settings.ambientVolume, in: 0.05...1.0) {
                        Text("Ambient Volume: \(Int(settings.ambientVolume * 100))%")
                    }
                }
                .padding(10)
            }
        }
    }
    
    // MARK: - Sync & Cloud Tab
    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Free Apple iCloud Sync
            GroupBox(label: Text("Free Apple iCloud Sync").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Sync Sessions & Streaks to Apple iCloud Drive", isOn: $settings.iCloudSyncEnabled)
                        .onChange(of: settings.iCloudSyncEnabled) { enabled in
                            if enabled {
                                HistoryManager.shared.saveSessions()
                            }
                        }
                    
                    HStack {
                        Image(systemName: CloudSyncManager.shared.isICloudAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(CloudSyncManager.shared.isICloudAvailable ? .green : .orange)
                        Text(CloudSyncManager.shared.isICloudAvailable ? "iCloud Drive is active on this Mac (100% Free)" : "iCloud Drive not detected in standard location")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Uses your free Apple iCloud storage (~/Library/Mobile Documents/com~apple~CloudDocs/FlowApp) to automatically sync and back up your focus history, streaks, and settings across your Macs.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
            
            // Free Custom Cloud Endpoint (JSONBin / Supabase / Webhook)
            GroupBox(label: Text("Free Custom Cloud Sync / Webhook").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Custom Cloud Sync", isOn: $settings.customCloudSyncEnabled)
                    
                    if settings.customCloudSyncEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cloud Endpoint URL (e.g. JSONBin.io, Supabase, Firebase, Webhook):")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            TextField("https://api.jsonbin.io/v3/b/...", text: Binding(
                                get: { CloudSyncManager.shared.cloudEndpointURL },
                                set: {
                                    CloudSyncManager.shared.cloudEndpointURL = $0
                                    CloudSyncManager.shared.saveSettings()
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("API Key / Bearer Token (optional):")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            SecureField("Secret Key", text: Binding(
                                get: { CloudSyncManager.shared.cloudAPIKey },
                                set: {
                                    CloudSyncManager.shared.cloudAPIKey = $0
                                    CloudSyncManager.shared.saveSettings()
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    Text("Connect to any free cloud database (like JSONBin free tier or Supabase) to keep a remote backup of your sessions.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
            
            // Apple Calendar Sync
            GroupBox(label: Text("Apple Calendar Integration").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Log Completed Focus Sessions to Apple Calendar", isOn: $settings.calendarSyncEnabled)
                    
                    TextField("Calendar Name:", text: $settings.calendarName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Flow will automatically create timeline entries for every completed focus session in Apple Calendar.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(10)
            }
        }
    }
}
