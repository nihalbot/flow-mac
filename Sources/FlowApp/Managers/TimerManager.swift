import SwiftUI
import Combine

public class TimerManager: ObservableObject {
    public static let shared = TimerManager()
    
    @Published public var state: SessionState = .ready(type: .focus)
    @Published public var timeRemaining: TimeInterval = 25 * 60
    @Published public var totalDuration: TimeInterval = 25 * 60
    @Published public var currentRound: Int = 1
    @Published public var currentTitle: String = ""
    @Published public var currentCategory: SessionCategory = SessionCategory.defaultCategories.first!
    
    @Published public var showCommitmentWarning: Bool = false
    @Published public var isFullScreenBreakPresented: Bool = false
    
    private var lastCompletedFocusSessionDate: Date?
    private var timerCancellable: AnyCancellable?
    private var targetEndTime: Date?
    private var sessionStartTime: Date?
    
    private let settings = AppSettings.shared
    private let soundEngine = SoundEngine.shared
    private let blocker = DistractionBlocker.shared
    private let history = HistoryManager.shared
    private let calendarManager = CalendarManager.shared
    private let notificationManager = NotificationManager.shared
    
    public init() {
        self.timeRemaining = TimeInterval(settings.focusDurationMinutes * 60)
        self.totalDuration = TimeInterval(settings.focusDurationMinutes * 60)
        
        // Connect Hotkeys
        HotkeyManager.shared.onPlayPause = { [weak self] in
            self?.togglePlayPause()
        }
        HotkeyManager.shared.onSkip = { [weak self] in
            self?.skipSession()
        }
        HotkeyManager.shared.onReset = { [weak self] in
            self?.resetCurrentSession()
        }
    }
    
    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = totalDuration - timeRemaining
        return max(0.0, min(1.0, elapsed / totalDuration))
    }
    
    public var formattedTime: String {
        let totalSeconds = max(0, Int(ceil(timeRemaining)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public func updateTitle(_ newTitle: String) {
        currentTitle = newTitle
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Only update the last completed session if it finished within the last 120s and user hasn't started a new session
        if let lastCompleted = lastCompletedFocusSessionDate,
           Date().timeIntervalSince(lastCompleted) < 120,
           (state.isBreak || state.isIdle) {
            history.updateLastSessionTitle(trimmed)
            calendarManager.updateLastEventTitle(newTitle: trimmed)
        }
    }
    
    // MARK: - Actions
    
    public func togglePlayPause() {
        switch state {
        case .idle:
            startFocus()
        case .ready(let type):
            startSession(type: type, duration: totalDuration)
        case .running(let type):
            if type == .focus && settings.commitmentMode {
                // Flow Pro Commitment Mode: Show friction prompt
                showCommitmentWarning = true
            } else {
                pause()
            }
        case .paused(let type):
            resume(type: type)
        }
    }
    
    public func confirmBreakCommitment() {
        showCommitmentWarning = false
        pause()
    }
    
    public func startFocus() {
        let duration = TimeInterval(settings.focusDurationMinutes * 60)
        startSession(type: .focus, duration: duration)
    }
    
    public func startShortBreak() {
        let duration = TimeInterval(settings.shortBreakDurationMinutes * 60)
        startSession(type: .shortBreak, duration: duration)
    }
    
    public func startLongBreak() {
        let duration = TimeInterval(settings.longBreakDurationMinutes * 60)
        startSession(type: .longBreak, duration: duration)
    }
    
    public func startCustomBreak(durationMinutes: Int) {
        let duration = TimeInterval(durationMinutes * 60)
        let type: SessionType = durationMinutes >= settings.longBreakDurationMinutes ? .longBreak : .shortBreak
        startSession(type: type, duration: duration)
    }
    
    public func extendSession(by seconds: TimeInterval = 300) {
        totalDuration += seconds
        timeRemaining += seconds
        if let currentTarget = targetEndTime {
            targetEndTime = currentTarget.addingTimeInterval(seconds)
        } else {
            targetEndTime = Date().addingTimeInterval(timeRemaining)
        }
    }
    
    private func startSession(type: SessionType, duration: TimeInterval) {
        state = .running(type: type)
        totalDuration = duration
        timeRemaining = duration
        sessionStartTime = Date()
        targetEndTime = Date().addingTimeInterval(duration)
        
        if type == .focus {
            isFullScreenBreakPresented = false
            if settings.blockAppsEnabled || settings.blockWebsitesEnabled {
                blocker.startMonitoring()
            }
            if settings.ambientSound != .none {
                soundEngine.setAmbientSound(settings.ambientSound, volume: Float(settings.ambientVolume))
            }
        } else {
            blocker.stopMonitoring()
            soundEngine.stopAmbient()
            if settings.fullscreenBreaks {
                isFullScreenBreakPresented = true
            }
        }
        
        startTimerLoop()
    }
    
    public func pause() {
        guard case .running(let type) = state else { return }
        state = .paused(type: type)
        stopTimerLoop()
        
        if type == .focus {
            blocker.stopMonitoring()
            soundEngine.stopAmbient()
        }
    }
    
    public func resume(type: SessionType) {
        state = .running(type: type)
        targetEndTime = Date().addingTimeInterval(timeRemaining)
        
        if type == .focus {
            if settings.blockAppsEnabled || settings.blockWebsitesEnabled {
                blocker.startMonitoring()
            }
            if settings.ambientSound != .none {
                soundEngine.setAmbientSound(settings.ambientSound, volume: Float(settings.ambientVolume))
            }
        }
        
        startTimerLoop()
    }
    
    public func skipSession() {
        stopTimerLoop()
        blocker.stopMonitoring()
        soundEngine.stopAmbient()
        isFullScreenBreakPresented = false
        
        switch state {
        case .running(let type), .paused(let type), .ready(let type):
            if type == .focus {
                // Skipped focus: move to break
                advanceToBreak(wasCompleted: false)
            } else {
                // Skipped break: move to focus
                advanceToFocus()
            }
        case .idle:
            startFocus()
        }
    }
    
    public func resetCurrentSession() {
        stopTimerLoop()
        blocker.stopMonitoring()
        soundEngine.stopAmbient()
        isFullScreenBreakPresented = false
        
        switch state {
        case .running(let type), .paused(let type), .ready(let type):
            let duration: TimeInterval
            switch type {
            case .focus: duration = TimeInterval(settings.focusDurationMinutes * 60)
            case .shortBreak: duration = TimeInterval(settings.shortBreakDurationMinutes * 60)
            case .longBreak: duration = TimeInterval(settings.longBreakDurationMinutes * 60)
            }
            totalDuration = duration
            timeRemaining = duration
            state = .ready(type: type)
        case .idle:
            let duration = TimeInterval(settings.focusDurationMinutes * 60)
            totalDuration = duration
            timeRemaining = duration
            state = .ready(type: .focus)
        }
    }
    
    // MARK: - Loop & Completion
    
    private func startTimerLoop() {
        stopTimerLoop()
        timerCancellable = Timer.publish(every: 1.0, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func stopTimerLoop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }
    
    private func tick() {
        guard let targetEndTime = targetEndTime else { return }
        let remaining = targetEndTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            timeRemaining = 0
            completeCurrentSession()
        } else {
            timeRemaining = remaining
        }
    }
    
    private func completeCurrentSession() {
        stopTimerLoop()
        blocker.stopMonitoring()
        soundEngine.stopAmbient()
        
        guard case .running(let type) = state else { return }
        
        if type == .focus {
            lastCompletedFocusSessionDate = Date()
            let sessionRecord = FlowSession(
                title: currentTitle.isEmpty ? "Focus Session" : currentTitle,
                categoryName: currentCategory.name,
                startTime: sessionStartTime ?? Date().addingTimeInterval(-totalDuration),
                endTime: Date(),
                durationSeconds: totalDuration,
                completed: true,
                type: .focus
            )
            
            // Record stats & Apple Calendar
            history.recordSession(sessionRecord)
            calendarManager.logSessionToCalendar(session: sessionRecord)
            
            // Audio alert
            if settings.soundAlertsEnabled {
                soundEngine.playAlert(settings.focusSound, volume: Float(settings.soundVolume))
            }
            
            let breakMinutes = (currentRound % settings.longBreakInterval == 0)
                ? settings.longBreakDurationMinutes
                : settings.shortBreakDurationMinutes
            
            notificationManager.showFocusCompletedNotification(
                sessionName: currentTitle.isEmpty ? "Focus Session" : currentTitle,
                breakMinutes: breakMinutes
            )
            
            advanceToBreak(wasCompleted: true)
            
        } else {
            // Break completed
            isFullScreenBreakPresented = false
            
            if settings.soundAlertsEnabled {
                soundEngine.playAlert(settings.breakSound, volume: Float(settings.soundVolume))
            }
            
            notificationManager.showBreakCompletedNotification(
                nextSessionName: currentTitle.isEmpty ? "Focus Session" : currentTitle
            )
            
            advanceToFocus()
        }
    }
    
    private func advanceToBreak(wasCompleted: Bool) {
        if wasCompleted {
            if currentRound >= settings.longBreakInterval {
                currentRound = 1
                let duration = TimeInterval(settings.longBreakDurationMinutes * 60)
                if settings.autoStartBreaks {
                    startSession(type: .longBreak, duration: duration)
                } else {
                    prepareSession(type: .longBreak, duration: duration)
                }
            } else {
                currentRound += 1
                let duration = TimeInterval(settings.shortBreakDurationMinutes * 60)
                if settings.autoStartBreaks {
                    startSession(type: .shortBreak, duration: duration)
                } else {
                    prepareSession(type: .shortBreak, duration: duration)
                }
            }
        } else {
            let duration = TimeInterval(settings.shortBreakDurationMinutes * 60)
            prepareSession(type: .shortBreak, duration: duration)
        }
    }
    
    private func advanceToFocus() {
        let duration = TimeInterval(settings.focusDurationMinutes * 60)
        if settings.autoStartFocus {
            startSession(type: .focus, duration: duration)
        } else {
            prepareSession(type: .focus, duration: duration)
        }
    }
    
    private func prepareSession(type: SessionType, duration: TimeInterval) {
        state = .ready(type: type)
        totalDuration = duration
        timeRemaining = duration
        if type != .focus && settings.fullscreenBreaks {
            isFullScreenBreakPresented = true
        }
    }
}
