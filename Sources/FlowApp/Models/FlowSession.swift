import Foundation

public struct FlowSession: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var categoryName: String
    public var startTime: Date
    public var endTime: Date
    public var durationSeconds: TimeInterval
    public var completed: Bool
    public var type: SessionType
    
    public init(
        id: UUID = UUID(),
        title: String,
        categoryName: String,
        startTime: Date,
        endTime: Date,
        durationSeconds: TimeInterval,
        completed: Bool,
        type: SessionType
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.type = type
    }
    
    public var durationMinutes: Int {
        Int(durationSeconds / 60)
    }
}
