import SwiftUI
import Combine

public struct MenuBarHUDView: View {
    @ObservedObject var timer = TimerManager.shared
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var soundEngine = SoundEngine.shared
    @ObservedObject var history = HistoryManager.shared
    @ObservedObject var blocker = DistractionBlocker.shared
    
    public var onOpenStats: () -> Void
    public var onOpenSettings: () -> Void
    public var onOpenFullScreenBreak: () -> Void
    public var onQuit: () -> Void
    
    public init(
        onOpenStats: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {},
        onOpenFullScreenBreak: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.onOpenStats = onOpenStats
        self.onOpenSettings = onOpenSettings
        self.onOpenFullScreenBreak = onOpenFullScreenBreak
        self.onQuit = onQuit
    }
    
    private var currentAccentColor: Color {
        if let type = timer.state.currentType {
            return type.accentColor
        }
        return timer.currentCategory.color
    }
    
    private var mainButtonTitle: String {
        switch timer.state {
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .ready(let type):
            return "Start \(type.displayName)"
        case .idle:
            return "Start Focus"
        }
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(currentAccentColor)
                    Text("Flow")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                // Round Pill
                HStack(spacing: 4) {
                    Text("Round \(timer.currentRound)/\(settings.longBreakInterval)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
                
                // Streak Pill
                HStack(spacing: 3) {
                    Text("🔥 \(history.currentStreakDays)d")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 4)
            
            // Distraction Shield Banner (if active blocked app or site detected)
            if let blockedApp = blocker.blockedAppDetected {
                HStack(spacing: 6) {
                    Image(systemName: "shield.slash.fill")
                        .foregroundColor(.white)
                    Text("\(blockedApp) was blocked to preserve flow")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(8)
                .background(Color.red.opacity(0.85))
                .cornerRadius(8)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let blockedSite = blocker.blockedSiteDetected {
                HStack(spacing: 6) {
                    Image(systemName: "globe.badge.chevron.backward")
                        .foregroundColor(.white)
                    Text("\(blockedSite) blocked during Focus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.85))
                .cornerRadius(8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Circular Progress Display
            CircularTimerProgress(
                progress: timer.progress,
                timeString: timer.formattedTime,
                statusText: timer.state.statusDescription,
                roundText: "\(timer.currentCategory.name)",
                accentColor: currentAccentColor,
                lineWidth: 10,
                size: 190
            )
            .padding(.vertical, 4)
            
            // Session Title Input & Category Chips
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: timer.currentCategory.icon)
                        .font(.system(size: 12))
                        .foregroundColor(timer.currentCategory.color)
                    
                    TextField("What are you focusing on?", text: $timer.currentTitle, onCommit: {
                        timer.updateTitle(timer.currentTitle)
                    })
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 13, weight: .medium))
                    
                    if !timer.currentTitle.isEmpty {
                        Button(action: { timer.currentTitle = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                // Categories Horizontal Strip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(settings.categories) { cat in
                            let isSelected = timer.currentCategory.id == cat.id
                            Button(action: {
                                timer.currentCategory = cat
                            }) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(cat.color)
                                        .frame(width: 6, height: 6)
                                    Text(cat.name)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isSelected ? cat.color.opacity(0.2) : Color.secondary.opacity(0.1))
                                .foregroundColor(isSelected ? cat.color : .secondary)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            
            // Main Controls
            HStack(spacing: 12) {
                // Reset Button
                Button(action: {
                    timer.resetCurrentSession()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reset Session (⌘⌥R)")
                
                // Play / Pause Main CTA Button
                Button(action: {
                    timer.togglePlayPause()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: timer.state.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(mainButtonTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(currentAccentColor)
                    .foregroundColor(.white)
                    .cornerRadius(21)
                    .shadow(color: currentAccentColor.opacity(0.3), radius: 6, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Start or Pause (⌘⌥Space)")
                
                // Skip Button
                Button(action: {
                    timer.skipSession()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Skip Session (⌘⌥S)")
            }
            
            Divider()
                .padding(.vertical, 2)
            
            // Ambient Noise Selector Bar
            HStack {
                Menu {
                    ForEach(AmbientSound.allCases) { sound in
                        Button(action: {
                            settings.ambientSound = sound
                            if timer.state.isRunning && timer.state.isFocus {
                                soundEngine.setAmbientSound(sound, volume: Float(settings.ambientVolume))
                            }
                        }) {
                            HStack {
                                Text(sound.rawValue)
                                if settings.ambientSound == sound {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: settings.ambientSound == .none ? "speaker.slash" : "headphones")
                            .font(.system(size: 11))
                        Text(settings.ambientSound == .none ? "Ambient Sound" : settings.ambientSound.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(settings.ambientSound == .none ? .secondary : currentAccentColor)
                }
                .menuStyle(BorderlessButtonMenuStyle())
                
                Spacer()
                
                if settings.commitmentMode {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("Commitment")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            // Footer Action Icons
            HStack(spacing: 16) {
                // Break Preview / Mindfulness View
                Button(action: onOpenFullScreenBreak) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Distraction-Free Mindfulness Break View")
                
                // Analytics Dashboard
                Button(action: onOpenStats) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Focus Analytics & Streaks")
                
                // Preferences Window
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Preferences...")
                
                Spacer()
                
                // Quit App
                Button(action: onQuit) {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Quit Flow")
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(width: 300)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
        .alert(isPresented: $timer.showCommitmentWarning) {
            Alert(
                title: Text("Commitment Mode Active"),
                message: Text("You pledged to complete this focus session without distractions. Are you sure you want to pause early?"),
                primaryButton: .destructive(Text("Pause Anyway")) {
                    timer.confirmBreakCommitment()
                },
                secondaryButton: .cancel(Text("Keep Focusing"))
            )
        }
    }
}

// macOS Visual Effect Blur helper
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    
    public init(material: NSVisualEffectView.Material = .popover, blendingMode: NSVisualEffectView.BlendingMode = .behindWindow) {
        self.material = material
        self.blendingMode = blendingMode
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
