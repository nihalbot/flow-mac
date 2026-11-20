import Foundation

public enum AlertSound: String, CaseIterable, Codable, Identifiable {
    case bell = "Zen Bell"
    case singingBowl = "Singing Bowl"
    case digitalChime = "Digital Chime"
    case marimba = "Marimba Sparkle"
    case gong = "Tibetan Gong"
    
    public var id: String { rawValue }
}

public enum AmbientSound: String, CaseIterable, Codable, Identifiable {
    case none = "Off"
    case metronome = "Clock Ticking"
    case rain = "Gentle Rain (Pink Noise)"
    case ocean = "Ocean Waves (Brown Noise)"
    case whiteNoise = "Focus Mask (White Noise)"
    
    public var id: String { rawValue }
}
