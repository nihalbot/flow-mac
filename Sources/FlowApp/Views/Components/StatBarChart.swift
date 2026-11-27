import SwiftUI

public enum BarChartMode: String, CaseIterable, Identifiable {
    case days7 = "7 Days"
    case days14 = "14 Days"
    case hourly = "24h Activity"
    
    public var id: String { rawValue }
}

public class StatBarChartViewModel: ObservableObject {
    @Published public var selectedMode: BarChartMode = .days7
    @Published public var selectedDayId: String? = nil
    @Published public var selectedHour: Int? = nil
    
    public init() {}
}

public struct StatBarChart: View {
    @ObservedObject public var history: HistoryManager
    public var hourlyData: [Int: Int]
    public var accentColor: Color
    
    @StateObject private var vm = StatBarChartViewModel()
    
    public init(
        history: HistoryManager = HistoryManager.shared,
        hourlyData: [Int: Int]? = nil,
        accentColor: Color = Color(red: 0.95, green: 0.36, blue: 0.30)
    ) {
        self.history = history
        self.hourlyData = hourlyData ?? history.hourlyDistribution
        self.accentColor = accentColor
    }
    
    private var dailyStats: [DailyStudyStat] {
        switch vm.selectedMode {
        case .days7:
            return history.dailyStudyStats(days: 7)
        case .days14:
            return history.dailyStudyStats(days: 14)
        case .hourly:
            return []
        }
    }
    
    private var maxDayCycles: Int {
        let maxVal = dailyStats.map(\.totalCycles).max() ?? 1
        return max(maxVal, 1)
    }
    
    private var maxHourlyCount: Int {
        let maxVal = hourlyData.values.max() ?? 1
        return max(maxVal, 1)
    }
    
    private var currentSelectedDay: DailyStudyStat? {
        if let id = vm.selectedDayId {
            return dailyStats.first(where: { $0.id == id })
        }
        return dailyStats.first(where: { $0.isToday }) ?? dailyStats.last
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with Mode Picker
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundColor(accentColor)
                        Text("Study Cycles Activity")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    Text("Click any day bar to view total cycles and focus time")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: $vm.selectedMode) {
                    ForEach(BarChartMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 220)
            }
            
            // Chart Display
            if vm.selectedMode == .hourly {
                hourlyChartView
            } else {
                dailyChartView
            }
            
            // Detail Inspection Card (when day or hour is clicked)
            if vm.selectedMode != .hourly, let day = currentSelectedDay {
                dayDetailCard(day: day)
            } else if vm.selectedMode == .hourly, let hour = vm.selectedHour {
                hourDetailCard(hour: hour)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .onAppear {
            if vm.selectedDayId == nil {
                vm.selectedDayId = dailyStats.first(where: { $0.isToday })?.id ?? dailyStats.last?.id
            }
        }
    }
    
    // MARK: - Daily Study Cycle Bars
    
    private var dailyChartView: some View {
        HStack(alignment: .bottom, spacing: vm.selectedMode == .days14 ? 6 : 10) {
            ForEach(dailyStats) { stat in
                let isSelected = (currentSelectedDay?.id == stat.id)
                let heightFraction = CGFloat(stat.totalCycles) / CGFloat(maxDayCycles)
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        vm.selectedDayId = stat.id
                    }
                }) {
                    VStack(spacing: 6) {
                        // Cycles label above bar
                        if stat.totalCycles > 0 {
                            Text("\(stat.totalCycles)")
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? accentColor : .secondary)
                        } else {
                            Text("0")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                        
                        // The Bar
                        ZStack(alignment: .bottom) {
                            // Track background
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(height: 75)
                            
                            // Filled Bar
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    isSelected
                                        ? LinearGradient(colors: [accentColor, Color.orange], startPoint: .top, endPoint: .bottom)
                                        : (stat.totalCycles > 0
                                            ? LinearGradient(colors: [accentColor.opacity(0.85), accentColor], startPoint: .top, endPoint: .bottom)
                                            : LinearGradient(colors: [Color.secondary.opacity(0.15), Color.secondary.opacity(0.15)], startPoint: .top, endPoint: .bottom))
                                )
                                .frame(height: max(6, heightFraction * 75))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.5)
                                )
                                .shadow(color: isSelected ? accentColor.opacity(0.45) : Color.clear, radius: 5, y: 2)
                        }
                        
                        // Day Label & Date
                        VStack(spacing: 1) {
                            Text(stat.dayLabel)
                                .font(.system(size: vm.selectedMode == .days14 ? 9 : 11, weight: isSelected || stat.isToday ? .bold : .medium))
                                .foregroundColor(stat.isToday ? accentColor : (isSelected ? .primary : .secondary))
                            
                            Text("\(stat.dayNumber)")
                                .font(.system(size: vm.selectedMode == .days14 ? 8 : 9))
                                .foregroundColor(isSelected ? .primary : .secondary)
                        }
                        
                        // Active selection indicator pip
                        Circle()
                            .fill(isSelected ? accentColor : Color.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 125)
        .padding(.vertical, 4)
    }
    
    // MARK: - Selected Day Inspector Detail Card
    
    private func dayDetailCard(day: DailyStudyStat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header of clicked day
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(accentColor)
                    Text(day.fullDateString)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                
                if day.isToday {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor.opacity(0.15))
                        .foregroundColor(accentColor)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Text("Selected Day")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Total Cycle & Total Time Spent Badges
            HStack(spacing: 12) {
                // 1. Total Cycles Badge
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: "bolt.fill")
                            .foregroundColor(accentColor)
                            .font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Study Cycles")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("\(day.totalCycles) \(day.totalCycles == 1 ? "Cycle" : "Cycles")")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                .cornerRadius(10)
                
                // 2. Total Time Spent Badge
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Time Spent")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(day.formattedDuration)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                .cornerRadius(10)
            }
            
            // Completed Activities (Combined by Task & Category)
            if !day.sessions.isEmpty {
                let dayActivities = history.groupedActivities(from: day.sessions)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Day Activities (\(dayActivities.count)):")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Combined total time")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(dayActivities) { act in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 7, height: 7)
                                Text(act.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                
                                Text(act.categoryName)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                                
                                Spacer()
                                
                                Text("\(act.totalCycles) \(act.totalCycles == 1 ? "cycle" : "cycles") • \(act.formattedDuration)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 2)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("No study cycles recorded for this day.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
    }
    
    // MARK: - 24-Hour Activity View
    
    private var hourlyChartView: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<24, id: \.self) { hour in
                let count = hourlyData[hour] ?? 0
                let heightFraction = CGFloat(count) / CGFloat(maxHourlyCount)
                let isSelected = (vm.selectedHour == hour)
                
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        vm.selectedHour = hour
                    }
                }) {
                    VStack(spacing: 4) {
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                isSelected
                                    ? Color.orange
                                    : (count > 0 ? accentColor : Color.secondary.opacity(0.15))
                            )
                            .frame(height: max(4, heightFraction * 70))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1)
                            )
                        
                        if hour % 4 == 0 {
                            Text("\(hour)")
                                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .primary : .secondary)
                        } else {
                            Text("")
                                .font(.system(size: 9))
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(height: 90)
    }
    
    private func hourDetailCard(hour: Int) -> some View {
        let count = hourlyData[hour] ?? 0
        return HStack {
            Image(systemName: "clock")
                .foregroundColor(accentColor)
            Text("Hour \(String(format: "%02d:00", hour)) - \(String(format: "%02d:00", (hour + 1) % 24)):")
                .font(.system(size: 12, weight: .semibold))
            Text("\(count) Sessions (\(count * 25) mins)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }
}
