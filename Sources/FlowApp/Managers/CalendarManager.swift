import Foundation
import EventKit
import Combine

public class CalendarManager: ObservableObject {
    public static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    @Published public var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published public var lastLoggedEventIdentifier: String?
    @Published public var lastLoggedEventDate: Date?
    
    public init() {
        checkStatus()
    }
    
    public func checkStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    public var isAuthorized: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    public func requestAccess(completion: @escaping (Bool) -> Void = { _ in }) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.checkStatus()
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.checkStatus()
                    completion(granted)
                }
            }
        }
    }
    
    public func logSessionToCalendar(session: FlowSession) {
        let settings = AppSettings.shared
        guard settings.calendarSyncEnabled else { return }
        
        checkStatus()
        
        if !isAuthorized && authorizationStatus == .notDetermined {
            // First time: request permission once
            requestAccess { [weak self] granted in
                if granted {
                    self?.performSave(session: session)
                } else {
                    print("Flow: Calendar permission was not granted by user.")
                }
            }
        } else if isAuthorized {
            // Already authorized: directly save in background with zero prompts
            performSave(session: session)
        } else {
            print("Flow: Calendar permission is currently denied or restricted in System Settings.")
        }
    }
    
    private func performSave(session: FlowSession) {
        let settings = AppSettings.shared
        let targetCalName = settings.calendarName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Flow" : settings.calendarName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let calendar = self.getOrCreateTargetCalendar(named: targetCalName) else {
                print("Flow: Could not find or create target calendar '\(targetCalName)'")
                return
            }
            
            let event = EKEvent(eventStore: self.eventStore)
            let rawTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let eventTitle = "⚡ Flow: \(rawTitle.isEmpty ? "Focus Session" : rawTitle)"
            
            event.title = eventTitle
            event.startDate = session.startTime
            event.endDate = session.endTime
            event.calendar = calendar
            event.notes = "Tag: \(session.categoryName) | Duration: \(session.durationMinutes) min\nLogged automatically by Flow"
            
            do {
                try self.eventStore.save(event, span: .thisEvent, commit: true)
                let eventId = event.eventIdentifier
                DispatchQueue.main.async {
                    self.lastLoggedEventIdentifier = eventId
                    self.lastLoggedEventDate = Date()
                }
                print("Flow: Calendar event logged successfully: \(eventTitle) (Calendar: \(calendar.title))")
            } catch {
                print("Flow: Error saving event to Calendar: \(error.localizedDescription)")
            }
        }
    }
    
    private func getOrCreateTargetCalendar(named targetName: String) -> EKCalendar? {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title.caseInsensitiveCompare(targetName) == .orderedSame }) {
            return existing
        }
        
        // Try creating calendar
        let newCal = EKCalendar(for: .event, eventStore: eventStore)
        newCal.title = targetName
        
        let sources = eventStore.sources
        if let iCloud = sources.first(where: { $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("iCloud") }) {
            newCal.source = iCloud
        } else if let local = sources.first(where: { $0.sourceType == .local }) {
            newCal.source = local
        } else if let defaultCal = eventStore.defaultCalendarForNewEvents {
            newCal.source = defaultCal.source
        } else if let firstSource = sources.first {
            newCal.source = firstSource
        }
        
        do {
            try eventStore.saveCalendar(newCal, commit: true)
            return newCal
        } catch {
            print("Flow: Could not create calendar '\(targetName)', falling back to default calendar: \(error.localizedDescription)")
            return eventStore.defaultCalendarForNewEvents ?? calendars.first
        }
    }
    
    public func updateLastEventTitle(newTitle: String) {
        guard let eventId = lastLoggedEventIdentifier else { return }
        
        // Only update if logged within the last 30 minutes
        if let logDate = lastLoggedEventDate, Date().timeIntervalSince(logDate) > 1800 {
            return
        }
        
        let rawTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = "⚡ Flow: \(rawTitle.isEmpty ? "Focus Session" : rawTitle)"
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let event = self.eventStore.event(withIdentifier: eventId) {
                event.title = displayTitle
                do {
                    try self.eventStore.save(event, span: .thisEvent, commit: true)
                    print("Flow: Updated Apple Calendar event title to: \(displayTitle)")
                } catch {
                    print("Flow: Failed to update event title: \(error.localizedDescription)")
                }
            }
        }
    }
}
