import SwiftUI

public enum SessionType: String, Codable, CaseIterable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    public var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
    
    public var iconName: String {
        switch self {
        case .focus: return "bolt.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .focus: return Color(red: 0.95, green: 0.36, blue: 0.30) // Flow warm coral red
        case .shortBreak: return Color(red: 0.28, green: 0.72, blue: 0.60) // Calm mint teal
        case .longBreak: return Color(red: 0.33, green: 0.58, blue: 0.96) // Peaceful sky blue
        }
    }
}

public enum SessionState: Equatable {
    case idle
    case running(type: SessionType)
    case paused(type: SessionType)
    
    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
    
    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
    
    public var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
    
    public var currentType: SessionType? {
        switch self {
        case .idle: return nil
        case .running(let type): return type
        case .paused(let type): return type
        }
    }
    
    public var isBreak: Bool {
        guard let type = currentType else { return false }
        return type == .shortBreak || type == .longBreak
    }
    
    public var isFocus: Bool {
        return currentType == .focus
    }
    
    public var statusDescription: String {
        switch self {
        case .idle:
            return "Ready"
        case .running(let type):
            return type.displayName
        case .paused(let type):
            return "\(type.displayName) (Paused)"
        }
    }
}
