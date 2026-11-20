import Foundation
import EventKit

public class CalendarManager: ObservableObject {
    public static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    public init() {}
    
    public func requestAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }
    
    public func logSessionToCalendar(session: FlowSession) {
        let settings = AppSettings.shared
        guard settings.calendarSyncEnabled else { return }
        
        let targetCalendarName = settings.calendarName.isEmpty ? "Flow" : settings.calendarName
        let eventTitle = "⚡ Flow: \(session.title.isEmpty ? "Focus Session" : session.title)"
        let notes = "Tag: \(session.categoryName) | Duration: \(session.durationMinutes) min"
        
        let scriptSource = """
        tell application "Calendar"
            set targetCalName to "\(targetCalendarName)"
            set targetCal to missing value
            repeat with c in calendars
                if name of c is targetCalName then
                    set targetCal to c
                    exit repeat
                end if
            end repeat
            
            if targetCal is missing value then
                set targetCal to first calendar
            end if
            
            set startDate to current date
            set endDate to current date
            
            tell targetCal
                make new event with properties {summary:"\(eventTitle)", description:"\(notes)", start date:(current date - \(Int(session.durationSeconds))), end date:(current date)}
            end tell
        end tell
        """
        
        DispatchQueue.global(qos: .background).async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                script.executeAndReturnError(&error)
                if let error = error {
                    print("Calendar sync error: \(error)")
                } else {
                    print("Calendar event logged: \(eventTitle)")
                }
            }
        }
    }
}
