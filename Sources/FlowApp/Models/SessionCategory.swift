import SwiftUI

public struct SessionCategory: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var icon: String
    
    public init(id: UUID = UUID(), name: String, colorHex: String, icon: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
    }
    
    public var color: Color {
        Color(hex: colorHex)
    }
    
    public static let defaultCategories: [SessionCategory] = [
        SessionCategory(name: "Coding", colorHex: "#FF5F56", icon: "chevron.left.forwardslash.chevron.right"),
        SessionCategory(name: "Writing", colorHex: "#FFBD2E", icon: "pencil.and.outline"),
        SessionCategory(name: "Design", colorHex: "#A259FF", icon: "paintbrush.fill"),
        SessionCategory(name: "Study", colorHex: "#27C93F", icon: "book.fill"),
        SessionCategory(name: "Deep Work", colorHex: "#007AFF", icon: "brain.head.profile"),
        SessionCategory(name: "Personal", colorHex: "#FF2D55", icon: "person.fill")
    ]
}

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    public func toHex() -> String {
        // Fallback hex generator
        return "#FF5F56"
    }
}
