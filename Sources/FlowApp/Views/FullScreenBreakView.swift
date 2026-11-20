import SwiftUI
import Combine

public class BreakViewModel: ObservableObject {
    @Published public var currentTipIndex: Int = 0
    
    public init() {
        self.currentTipIndex = Int.random(in: 0..<6)
    }
    
    public func randomizeTip(count: Int) {
        if count > 0 {
            currentTipIndex = (currentTipIndex + 1) % count
        }
    }
}

public struct FullScreenBreakView: View {
    @ObservedObject var timer = TimerManager.shared
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var vm = BreakViewModel()
    
    public var onDismiss: () -> Void
    
    private let mindfulTips = [
        "Take a slow breath. Relax your shoulders and unclench your jaw.",
        "Look at an object at least 20 feet away for 20 seconds to rest your eyes.",
        "Stand up, stretch your arms above your head, and walk around a bit.",
        "Hydrate! Drink a fresh glass of water.",
        "Gently roll your neck from side to side and stretch your wrists.",
        "Let your thoughts drift freely. Your brain is consolidating what you learned."
    ]
    
    public init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    private var isCurrentlyOnBreak: Bool {
        if let type = timer.state.currentType {
            return type == .shortBreak || type == .longBreak
        }
        return false
    }
    
    public var body: some View {
        ZStack {
            // Background Dimmer / Backdrop
            Color.black.opacity(0.75)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            // Centered Main Mindfulness Card
            VStack(spacing: 18) {
                // Top Navigation Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.28, green: 0.72, blue: 0.60))
                        Text(isCurrentlyOnBreak ? (timer.state.currentType?.displayName ?? "Mindful Break") : "Mindfulness & Break Options")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 4)
                
                if isCurrentlyOnBreak {
                    // --- ACTIVE BREAK STATE ---
                    VStack(spacing: 8) {
                        Text(timer.formattedTime)
                            .font(.system(size: 50, weight: .thin, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("remaining in your break")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        
                        // Extend Break Buttons (+1m / +5m)
                        HStack(spacing: 10) {
                            Button(action: { timer.extendSession(by: 60) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("1 min")
                                }
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { timer.extendSession(by: 300) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("5 min")
                                }
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                } else {
                    // --- FOCUS / IDLE BREAK OPTIONS STATE ---
                    VStack(spacing: 12) {
                        Text("Step away to rest your eyes, relax your posture, and recharge.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        
                        // 3 Quick Start Break Action Cards
                        HStack(spacing: 12) {
                            // Short Break Option
                            Button(action: {
                                timer.startShortBreak()
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.28, green: 0.72, blue: 0.60))
                                    Text("Short Break")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("\(settings.shortBreakDurationMinutes) min")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Long Break Option
                            Button(action: {
                                timer.startLongBreak()
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.35, green: 0.75, blue: 0.95))
                                    Text("Long Break")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("\(settings.longBreakDurationMinutes) min")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 2-Min Reset Option
                            Button(action: {
                                timer.startCustomBreak(durationMinutes: 2)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: "wind")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.35))
                                    Text("2-Min Reset")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Breathwork")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Guided Breathing Orb
                BreathingCircleView(baseSize: 120)
                    .padding(.vertical, 2)
                
                // Mindful Tip Card
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.98, green: 0.82, blue: 0.35))
                        .padding(.top, 2)
                    
                    Text(mindfulTips[vm.currentTipIndex % mindfulTips.count])
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button(action: {
                        vm.randomizeTip(count: mindfulTips.count)
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Next Tip")
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
                
                // Bottom Action Buttons
                HStack(spacing: 12) {
                    if isCurrentlyOnBreak {
                        Button(action: {
                            timer.skipSession()
                            onDismiss()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                Text("End Break & Focus Now")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color(red: 0.28, green: 0.72, blue: 0.60))
                            .foregroundColor(.white)
                            .cornerRadius(19)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onDismiss) {
                            Text("Dismiss Window")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .frame(height: 38)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.8))
                                .cornerRadius(19)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        Button(action: {
                            timer.startShortBreak()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                Text("Start Short Break (5m)")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color(red: 0.28, green: 0.72, blue: 0.60))
                            .foregroundColor(.white)
                            .cornerRadius(19)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: onDismiss) {
                            Text("Back to Work (Esc)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .frame(height: 38)
                                .padding(.horizontal, 16)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white.opacity(0.8))
                                .cornerRadius(19)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(width: 480)
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                    .background(Color.black.opacity(0.88))
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 30, y: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            vm.randomizeTip(count: mindfulTips.count)
        }
    }
}
