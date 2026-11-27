import SwiftUI
import AppKit
import Combine

public enum StatsTab: String, CaseIterable {
    case overview = "Overview"
    case history = "History"
}

public enum HistoryViewMode: String, CaseIterable, Identifiable {
    case combined = "Combined Activities"
    case timeline = "All Sessions Timeline"
    public var id: String { rawValue }
}

public class StatsViewModel: ObservableObject {
    @Published public var selectedTab: StatsTab = .overview
    @Published public var historyViewMode: HistoryViewMode = .combined
    @Published public var isExporting: Bool = false
    @Published public var exportMessage: String? = nil
    @Published public var cloudMessage: String? = nil
    
    public init() {}
    
    public func triggerManualCloudSync(history: HistoryManager) {
        history.saveSessions()
        self.cloudMessage = "☁️ History Synced to Free Cloud!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.cloudMessage = nil
        }
    }
    
    public func exportCSVData(history: HistoryManager) {
        let csvContent = history.exportCSV()
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "Flow_History_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        
        savePanel.begin { [weak self] result in
            if result == .OK, let url = savePanel.url {
                try? csvContent.write(to: url, atomically: true, encoding: .utf8)
                self?.exportMessage = "Exported to \(url.lastPathComponent) successfully!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self?.exportMessage = nil
                }
            }
        }
    }
}

public struct StatsDashboardView: View {
    @ObservedObject var history = HistoryManager.shared
    @ObservedObject var settings = AppSettings.shared
    @StateObject private var vm = StatsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus Analytics")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Track your habits, streaks, and flow states over time")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $vm.selectedTab) {
                    ForEach(StatsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                if vm.selectedTab == .overview {
                    overviewContent
                } else {
                    historyContent
                }
            }
            .background(Color(NSColor.underPageBackgroundColor).opacity(0.3))
            
            Divider()
            
            // Footer
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(settings.iCloudSyncEnabled ? .blue : .secondary)
                    Text(CloudSyncManager.shared.syncStatus.displayText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if let msg = vm.cloudMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                if let msg = vm.exportMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button(action: {
                    vm.triggerManualCloudSync(history: history)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        Text("Sync to Cloud")
                    }
                }
                
                Button(action: {
                    vm.exportCSVData(history: history)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export CSV")
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 580, minHeight: 460)
    }
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Top Metrics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Today's Focus",
                    value: "\(history.todayFocusMinutes / 60)h \(history.todayFocusMinutes % 60)m",
                    icon: "clock.fill",
                    color: Color(red: 0.95, green: 0.36, blue: 0.30)
                )
                
                MetricCard(
                    title: "Current Streak",
                    value: "\(history.currentStreakDays) Days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                MetricCard(
                    title: "Best Streak",
                    value: "\(history.longestStreakDays) Days",
                    icon: "trophy.fill",
                    color: .yellow
                )
                
                MetricCard(
                    title: "Today's Goal",
                    value: "\(history.todaySessions.count) / \(settings.dailyTargetSessions)",
                    icon: "target",
                    color: Color(red: 0.28, green: 0.72, blue: 0.60)
                )
            }
            
            // Streak Progress & 7-Day Habit Tracker Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text(history.streakMilestoneTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    
                    Spacer()
                    
                    Text("Current: \(history.currentStreakDays)d • Best: \(history.longestStreakDays)d")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                // 7 Days Visual Tracker Row
                HStack(spacing: 12) {
                    ForEach(history.weeklyStreakStatus) { day in
                        VStack(spacing: 6) {
                            let dayLetter = String(day.weekdayName.prefix(1))
                            Text(dayLetter)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(day.isToday ? .orange : .secondary)
                            
                            ZStack {
                                Circle()
                                    .fill(day.isCompleted ? Color.orange : Color.secondary.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                
                                if day.isCompleted {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(day.dayNumber)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(day.isToday ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(12)
            
            // Study Cycles & Focus Activity Bar Chart (Clickable Day Bars)
            StatBarChart(history: history)
            
            // Category Breakdown Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Category Time Distribution")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                let breakdown = history.categoryBreakdown
                if breakdown.isEmpty {
                    Text("No categorized sessions recorded yet.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    let totalMin = max(1, breakdown.values.reduce(0, +))
                    ForEach(breakdown.sorted(by: { $0.value > $1.value }), id: \.key) { tag, minutes in
                        let fraction = Double(minutes) / Double(totalMin)
                        let matchingCat = settings.categories.first(where: { $0.name == tag })
                        let catColor = matchingCat?.color ?? Color.accentColor
                        
                        VStack(spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(catColor)
                                    .frame(width: 8, height: 8)
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text("\(minutes / 60)h \(minutes % 60)m (\(Int(fraction * 100))%)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(catColor)
                                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(12)
            
            // Activities & Tasks Breakdown (Combined Cycles & Time)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .foregroundColor(Color(red: 0.95, green: 0.36, blue: 0.30))
                        Text("Activities & Tasks Breakdown")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Spacer()
                    Text("Total combined time per task")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                let activities = history.groupedActivities()
                if activities.isEmpty {
                    Text("No activities recorded yet.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    let totalSecsAll = max(1.0, Double(activities.reduce(0) { $0 + $1.totalSeconds }))
                    ForEach(activities.prefix(10)) { act in
                        let fraction = act.totalSeconds / totalSecsAll
                        let matchingCat = settings.categories.first(where: { $0.name == act.categoryName })
                        let catColor = matchingCat?.color ?? Color(red: 0.95, green: 0.36, blue: 0.30)
                        
                        VStack(spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(catColor)
                                    .frame(width: 8, height: 8)
                                Text(act.title)
                                    .font(.system(size: 12, weight: .bold))
                                
                                Text(act.categoryName)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                                
                                Spacer()
                                
                                Text("\(act.totalCycles) \(act.totalCycles == 1 ? "cycle" : "cycles") • \(act.formattedDuration)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(catColor)
                                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(12)
        }
        .padding()
    }
    
    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if history.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No Completed Sessions Yet")
                        .font(.system(size: 14, weight: .medium))
                    Text("Complete your first focus session to view your history.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                // View Mode Picker (Combined vs Timeline)
                Picker("", selection: $vm.historyViewMode) {
                    ForEach(HistoryViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.bottom, 4)
                
                if vm.historyViewMode == .combined {
                    // Combined Activities View
                    let combined = history.groupedActivities()
                    ForEach(combined) { act in
                        let matchingCat = settings.categories.first(where: { $0.name == act.categoryName })
                        let catColor = matchingCat?.color ?? Color(red: 0.95, green: 0.36, blue: 0.30)
                        
                        HStack(spacing: 12) {
                            Image(systemName: matchingCat?.icon ?? "bolt.fill")
                                .font(.system(size: 14))
                                .foregroundColor(catColor)
                                .frame(width: 32, height: 32)
                                .background(catColor.opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(act.title)
                                    .font(.system(size: 13, weight: .bold))
                                
                                HStack(spacing: 6) {
                                    Text(act.categoryName)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(catColor.opacity(0.15))
                                        .foregroundColor(catColor)
                                        .clipShape(Capsule())
                                    
                                    Text("Latest: \(act.latestSessionDate.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(act.formattedDuration)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                
                                Text("\(act.totalCycles) \(act.totalCycles == 1 ? "cycle" : "cycles")")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                    }
                } else {
                    // Chronological Timeline View
                    let sorted = history.sessions.sorted(by: { $0.endTime > $1.endTime })
                    ForEach(sorted) { session in
                        HStack(spacing: 12) {
                            Image(systemName: session.type.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(session.type.accentColor)
                                .frame(width: 28, height: 28)
                                .background(session.type.accentColor.opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.system(size: 13, weight: .medium))
                                
                                HStack(spacing: 6) {
                                    Text(session.categoryName)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.12))
                                        .clipShape(Capsule())
                                    
                                    Text(session.endTime.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("\(session.durationMinutes) min")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

private struct MetricCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
    }
}
