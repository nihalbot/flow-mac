import Foundation
import Combine

public struct DayStreakStatus: Identifiable, Equatable {
    public var id: String { weekdayName }
    public var weekdayName: String
    public var dayNumber: Int
    public var isToday: Bool
    public var isCompleted: Bool
    
    public init(weekdayName: String, dayNumber: Int, isToday: Bool, isCompleted: Bool) {
        self.weekdayName = weekdayName
        self.dayNumber = dayNumber
        self.isToday = isToday
        self.isCompleted = isCompleted
    }
}

public struct DailyStudyStat: Identifiable, Equatable {
    public var id: String { dateKey }
    public var dateKey: String
    public var date: Date
    public var dayLabel: String
    public var dayNumber: Int
    public var fullDateString: String
    public var totalCycles: Int
    public var totalMinutes: Int
    public var isToday: Bool
    public var sessions: [FlowSession]
    
    public init(
        dateKey: String,
        date: Date,
        dayLabel: String,
        dayNumber: Int,
        fullDateString: String,
        totalCycles: Int,
        totalMinutes: Int,
        isToday: Bool,
        sessions: [FlowSession]
    ) {
        self.dateKey = dateKey
        self.date = date
        self.dayLabel = dayLabel
        self.dayNumber = dayNumber
        self.fullDateString = fullDateString
        self.totalCycles = totalCycles
        self.totalMinutes = totalMinutes
        self.isToday = isToday
        self.sessions = sessions
    }
    
    public var formattedDuration: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

public struct GroupedActivity: Identifiable, Equatable {
    public var id: String { "\(categoryName):::\(normalizedTitle.lowercased())" }
    public var title: String
    public var normalizedTitle: String
    public var categoryName: String
    public var totalSeconds: TimeInterval
    public var totalMinutes: Int { Int(totalSeconds / 60) }
    public var totalCycles: Int
    public var latestSessionDate: Date
    public var sessions: [FlowSession]
    
    public init(
        title: String,
        normalizedTitle: String,
        categoryName: String,
        totalSeconds: TimeInterval,
        totalCycles: Int,
        latestSessionDate: Date,
        sessions: [FlowSession]
    ) {
        self.title = title
        self.normalizedTitle = normalizedTitle
        self.categoryName = categoryName
        self.totalSeconds = totalSeconds
        self.totalCycles = totalCycles
        self.latestSessionDate = latestSessionDate
        self.sessions = sessions
    }
    
    public var formattedDuration: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
}

public class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()
    
    @Published public var sessions: [FlowSession] = []
    @Published public var currentStreakDays: Int = 0
    @Published public var longestStreakDays: Int = 0
    @Published public var streakMilestoneTitle: String = "Start Today"
    @Published public var weeklyStreakStatus: [DayStreakStatus] = []
    @Published public var todayFocusMinutes: Int = 0
    @Published public var weekFocusMinutes: Int = 0
    @Published public var totalFocusMinutes: Int = 0
    @Published public var totalSessionsCount: Int = 0
    
    private let fileURL: URL
    
    public init() {
        let fileManager = FileManager.default
        var targetDir: URL
        
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let flowDir = appSupport.appendingPathComponent("FlowApp", isDirectory: true)
            do {
                try fileManager.createDirectory(at: flowDir, withIntermediateDirectories: true, attributes: nil)
                targetDir = flowDir
            } catch {
                let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
                targetDir = caches.appendingPathComponent("FlowApp", isDirectory: true)
                try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
            }
        } else {
            targetDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FlowApp", isDirectory: true)
            try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.fileURL = targetDir.appendingPathComponent("sessions_history.json")
        loadSessions()
    }
    
    public func recordSession(_ session: FlowSession) {
        sessions.append(session)
        recalculateStats()
        saveSessions()
    }
    
    public func updateLastSessionTitle(_ newTitle: String) {
        guard !sessions.isEmpty else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lastIdx = sessions.count - 1
        sessions[lastIdx].title = trimmed
        saveSessions()
    }
    
    public func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL, options: .atomic)
            
            // Auto-sync to Free Apple iCloud Drive
            if AppSettings.shared.iCloudSyncEnabled {
                _ = CloudSyncManager.shared.syncToICloud(data: data)
            }
            
            // Auto-sync to Free Custom Cloud if enabled
            if AppSettings.shared.customCloudSyncEnabled {
                CloudSyncManager.shared.syncToFreeCloudEndpoint(data: data) { _ in }
            }
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
    
    public func loadSessions() {
        // First check if iCloud has newer or existing data
        if AppSettings.shared.iCloudSyncEnabled,
           let cloudData = CloudSyncManager.shared.fetchFromICloud(),
           let cloudSessions = try? JSONDecoder().decode([FlowSession].self, from: cloudData),
           !cloudSessions.isEmpty {
            self.sessions = cloudSessions
            recalculateStats()
            return
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            generateDemoDataIfEmpty()
            recalculateStats()
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            self.sessions = try JSONDecoder().decode([FlowSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
        recalculateStats()
    }
    
    public func recalculateStats() {
        let calendar = Calendar.current
        let today = Date()
        let focusSessions = sessions.filter { $0.type == .focus && $0.completed }
        
        totalSessionsCount = focusSessions.count
        totalFocusMinutes = focusSessions.reduce(0) { $0 + $1.durationMinutes }
        
        let todaySess = focusSessions.filter { calendar.isDateInToday($0.endTime) }
        todayFocusMinutes = todaySess.reduce(0) { $0 + $1.durationMinutes }
        
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) {
            weekFocusMinutes = focusSessions.filter { $0.endTime >= weekAgo }.reduce(0) { $0 + $1.durationMinutes }
        }
        
        // Calculate streak
        if focusSessions.isEmpty {
            currentStreakDays = 0
        } else {
            var streak = 0
            var checkDate = calendar.startOfDay(for: today)
            
            let todayCount = focusSessions.filter { calendar.isDate($0.endTime, inSameDayAs: checkDate) }.count
            if todayCount == 0 {
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                    let yesterdayCount = focusSessions.filter { calendar.isDate($0.endTime, inSameDayAs: yesterday) }.count
                    if yesterdayCount == 0 {
                        currentStreakDays = 0
                    } else {
                        checkDate = yesterday
                        streak = 1
                        while let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                            let count = focusSessions.filter { calendar.isDate($0.endTime, inSameDayAs: prev) }.count
                            if count > 0 {
                                streak += 1
                                checkDate = prev
                            } else {
                                break
                            }
                        }
                        currentStreakDays = streak
                    }
                }
            } else {
                streak = 1
                while let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                    let count = focusSessions.filter { calendar.isDate($0.endTime, inSameDayAs: prev) }.count
                    if count > 0 {
                        streak += 1
                        checkDate = prev
                    } else {
                        break
                    }
                }
                currentStreakDays = streak
            }
        }
        
        let best = AppSettings.shared.allTimeBestStreak
        if currentStreakDays > best {
            AppSettings.shared.allTimeBestStreak = currentStreakDays
        }
        longestStreakDays = max(AppSettings.shared.allTimeBestStreak, currentStreakDays)
        
        switch currentStreakDays {
        case 0: streakMilestoneTitle = "Start Today"
        case 1: streakMilestoneTitle = "Spark Ignited 🌱"
        case 2...3: streakMilestoneTitle = "In the Flow ⚡️"
        case 4...6: streakMilestoneTitle = "On Fire 🔥"
        case 7...13: streakMilestoneTitle = "Unstoppable Week 🚀"
        case 14...29: streakMilestoneTitle = "Focus Champion 👑"
        default: streakMilestoneTitle = "Flow Legend 💎"
        }
        
        // 7 days streak
        var weekList: [DayStreakStatus] = []
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayNum = calendar.component(.day, from: date)
            let weekdayIndex = calendar.component(.weekday, from: date)
            let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
            let symbol = weekdaySymbols[(weekdayIndex - 1) % 7]
            
            let count = focusSessions.filter { calendar.isDate($0.endTime, inSameDayAs: date) }.count
            let isToday = calendar.isDateInToday(date)
            
            weekList.append(
                DayStreakStatus(
                    weekdayName: "\(symbol)_\(offset)",
                    dayNumber: dayNum,
                    isToday: isToday,
                    isCompleted: count > 0
                )
            )
        }
        weeklyStreakStatus = weekList
    }
    
    private func generateDemoDataIfEmpty() {
        let now = Date()
        let calendar = Calendar.current
        var demoSessions: [FlowSession] = []
        
        // Add sample study cycles across the last 7 days (4, 3, 5, 2, 4, 3, 4 cycles)
        let sampleCounts = [4, 3, 5, 2, 4, 3, 4]
        for dayOffset in 0..<sampleCounts.count {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let count = sampleCounts[dayOffset]
            for i in 0..<count {
                let start = calendar.date(byAdding: .hour, value: -(i * 2 + 1), to: day)!
                let end = calendar.date(byAdding: .minute, value: 25, to: start)!
                let titles = ["Code review & refactoring", "UI system styling", "API integration", "Algorithm study", "Documentation writeup"]
                let tags = ["Coding", "Design", "Coding", "Study", "Writing"]
                
                demoSessions.append(
                    FlowSession(
                        title: titles[i % titles.count],
                        categoryName: tags[i % tags.count],
                        startTime: start,
                        endTime: end,
                        durationSeconds: 1500,
                        completed: true,
                        type: .focus
                    )
                )
            }
        }
        
        self.sessions = demoSessions
        saveSessions()
    }
    
    // MARK: - Daily Study Cycle Stats
    
    public func dailyStudyStats(days: Int = 7) -> [DailyStudyStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let df = DateFormatter()
        let focusSessions = sessions.filter { $0.type == .focus && $0.completed }
        
        var result: [DailyStudyStat] = []
        
        for offset in (0..<days).reversed() {
            guard let dayDate = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            let daySessions = focusSessions.filter {
                $0.endTime >= dayStart && $0.endTime < dayEnd
            }
            
            let cycles = daySessions.count
            let minutes = daySessions.reduce(0) { $0 + $1.durationMinutes }
            let isToday = calendar.isDateInToday(dayDate)
            
            df.dateFormat = "EEE"
            let shortDay = isToday ? "Today" : df.string(from: dayDate)
            let dayNum = calendar.component(.day, from: dayDate)
            
            df.dateFormat = "EEEE, MMM d"
            let fullDate = df.string(from: dayDate)
            
            df.dateFormat = "yyyy-MM-dd"
            let key = df.string(from: dayDate)
            
            result.append(
                DailyStudyStat(
                    dateKey: key,
                    date: dayDate,
                    dayLabel: shortDay,
                    dayNumber: dayNum,
                    fullDateString: fullDate,
                    totalCycles: cycles,
                    totalMinutes: minutes,
                    isToday: isToday,
                    sessions: daySessions
                )
            )
        }
        return result
    }
    
    // MARK: - Stats Calculations
    
    public var todaySessions: [FlowSession] {
        let calendar = Calendar.current
        return sessions.filter {
            $0.type == .focus && $0.completed && calendar.isDateInToday($0.endTime)
        }
    }
    
    // Hourly distribution: count of sessions completed per hour (0..23)
    public var hourlyDistribution: [Int: Int] {
        let calendar = Calendar.current
        var distribution: [Int: Int] = [:]
        for h in 0..<24 { distribution[h] = 0 }
        
        for session in sessions where session.type == .focus && session.completed {
            let hour = calendar.component(.hour, from: session.startTime)
            distribution[hour, default: 0] += 1
        }
        return distribution
    }
    
    // Category Breakdown: category name -> total minutes
    public var categoryBreakdown: [String: Int] {
        var breakdown: [String: Int] = [:]
        for session in sessions where session.type == .focus && session.completed {
            let cat = session.categoryName.isEmpty ? "General" : session.categoryName
            breakdown[cat, default: 0] += session.durationMinutes
        }
        return breakdown
    }
    
    // MARK: - Combined Activities Grouping
    
    public func groupedActivities(from sourceSessions: [FlowSession]? = nil) -> [GroupedActivity] {
        let input = sourceSessions ?? sessions.filter { $0.type == .focus && $0.completed }
        
        var grouped: [String: (title: String, category: String, totalSecs: TimeInterval, cycles: Int, latestDate: Date, list: [FlowSession])] = [:]
        
        for sess in input {
            let rawTitle = sess.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = rawTitle.isEmpty ? sess.categoryName : rawTitle
            let key = "\(sess.categoryName):::\(displayTitle.lowercased())"
            
            if var existing = grouped[key] {
                existing.totalSecs += sess.durationSeconds
                existing.cycles += 1
                if sess.endTime > existing.latestDate {
                    existing.latestDate = sess.endTime
                }
                existing.list.append(sess)
                grouped[key] = existing
            } else {
                grouped[key] = (
                    title: displayTitle,
                    category: sess.categoryName,
                    totalSecs: sess.durationSeconds,
                    cycles: 1,
                    latestDate: sess.endTime,
                    list: [sess]
                )
            }
        }
        
        return grouped.values.map { item in
            GroupedActivity(
                title: item.title,
                normalizedTitle: item.title,
                categoryName: item.category,
                totalSeconds: item.totalSecs,
                totalCycles: item.cycles,
                latestSessionDate: item.latestDate,
                sessions: item.list.sorted(by: { $0.endTime > $1.endTime })
            )
        }.sorted {
            if $0.totalSeconds != $1.totalSeconds {
                return $0.totalSeconds > $1.totalSeconds
            }
            return $0.latestSessionDate > $1.latestSessionDate
        }
    }
    
    public var todayGroupedActivities: [GroupedActivity] {
        return groupedActivities(from: todaySessions)
    }
    
    // CSV Export
    public func exportCSV() -> String {
        var csv = "ID,Title,Category,StartTime,EndTime,DurationMinutes,Completed\n"
        let df = ISO8601DateFormatter()
        for s in sessions {
            let safeTitle = s.title.replacingOccurrences(of: ",", with: " ")
            let safeCat = s.categoryName.replacingOccurrences(of: ",", with: " ")
            csv += "\(s.id),\"\(safeTitle)\",\"\(safeCat)\",\(df.string(from: s.startTime)),\(df.string(from: s.endTime)),\(s.durationMinutes),\(s.completed)\n"
        }
        return csv
    }
}
