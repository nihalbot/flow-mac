import SwiftUI

public struct CircularTimerProgress: View {
    public var progress: Double
    public var timeString: String
    public var statusText: String
    public var roundText: String
    public var accentColor: Color
    public var lineWidth: CGFloat = 12
    public var size: CGFloat = 220
    
    public init(
        progress: Double,
        timeString: String,
        statusText: String,
        roundText: String,
        accentColor: Color,
        lineWidth: CGFloat = 12,
        size: CGFloat = 220
    ) {
        self.progress = progress
        self.timeString = timeString
        self.statusText = statusText
        self.roundText = roundText
        self.accentColor = accentColor
        self.lineWidth = lineWidth
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(
                    accentColor.opacity(0.15),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
            
            // Progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Inner content
            VStack(spacing: 6) {
                Text(roundText.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
                
                Text(timeString)
                    .font(.system(size: size * 0.22, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text(statusText.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.2))
                    .foregroundColor(accentColor)
                    .clipShape(Capsule())
            }
        }
        .frame(width: size, height: size)
    }
}
