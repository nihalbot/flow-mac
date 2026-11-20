import SwiftUI
import Combine

public enum BreathingPhase: String {
    case inhale = "Breathe in slowly..."
    case holdIn = "Hold breath..."
    case exhale = "Breathe out gently..."
    case holdOut = "Relax and rest..."
}

public class BreathingViewModel: ObservableObject {
    @Published public var phase: BreathingPhase = .inhale
    @Published public var scale: CGFloat = 0.8
    @Published public var ringOpacity: Double = 0.3
    
    private var isActive: Bool = false
    
    public init() {}
    
    public func startBreathingCycle() {
        guard !isActive else { return }
        isActive = true
        animateStep()
    }
    
    public func stopBreathingCycle() {
        isActive = false
    }
    
    private func animateStep() {
        guard isActive else { return }
        
        // Inhale (4s)
        phase = .inhale
        scale = 1.25
        ringOpacity = 0.6
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            guard let self = self, self.isActive else { return }
            self.phase = .holdIn
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self = self, self.isActive else { return }
                self.phase = .exhale
                self.scale = 0.8
                self.ringOpacity = 0.2
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                    guard let self = self, self.isActive else { return }
                    self.phase = .holdOut
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                        guard let self = self, self.isActive else { return }
                        self.animateStep()
                    }
                }
            }
        }
    }
}

public struct BreathingCircleView: View {
    @StateObject private var vm = BreathingViewModel()
    public var baseSize: CGFloat
    
    public init(baseSize: CGFloat = 130) {
        self.baseSize = baseSize
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer subtle pulses
                Circle()
                    .fill(Color(red: 0.28, green: 0.72, blue: 0.60).opacity(0.12))
                    .frame(width: baseSize * 1.35, height: baseSize * 1.35)
                    .scaleEffect(vm.scale * 1.15)
                
                Circle()
                    .stroke(Color(red: 0.28, green: 0.72, blue: 0.60).opacity(vm.ringOpacity), lineWidth: 2)
                    .frame(width: baseSize * 1.15, height: baseSize * 1.15)
                    .scaleEffect(vm.scale)
                
                // Core breathing orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.28, green: 0.72, blue: 0.60).opacity(0.7),
                                Color(red: 0.20, green: 0.55, blue: 0.45).opacity(0.3)
                            ]),
                            center: .center,
                            startRadius: 5,
                            endRadius: baseSize * 0.5
                        )
                    )
                    .frame(width: baseSize * 0.85, height: baseSize * 0.85)
                    .scaleEffect(vm.scale)
                    .shadow(color: Color(red: 0.28, green: 0.72, blue: 0.60).opacity(0.4), radius: 14)
            }
            .animation(.easeInOut(duration: 4.0), value: vm.scale)
            
            Text(vm.phase.rawValue)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .transition(.opacity)
        }
        .frame(height: baseSize * 1.55)
        .onAppear {
            vm.startBreathingCycle()
        }
        .onDisappear {
            vm.stopBreathingCycle()
        }
    }
}
