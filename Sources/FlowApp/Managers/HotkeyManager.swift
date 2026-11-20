import Cocoa

public class HotkeyManager: ObservableObject {
    public static let shared = HotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    public var onPlayPause: (() -> Void)?
    public var onSkip: (() -> Void)?
    public var onReset: (() -> Void)?
    
    public init() {
        setupMonitors()
    }
    
    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupMonitors() {
        // Monitor key events locally when app is active or popover is open
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
        
        // Monitor global events
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmdOpt = flags.contains([.command, .option])
        
        guard isCmdOpt else { return false }
        
        switch event.keyCode {
        case 49, 35: // Space (49) or 'P' (35): Cmd+Opt+Space or Cmd+Opt+P -> Play / Pause
            DispatchQueue.main.async { [weak self] in
                self?.onPlayPause?()
            }
            return true
            
        case 1: // 'S' (1): Cmd+Opt+S -> Skip
            DispatchQueue.main.async { [weak self] in
                self?.onSkip?()
            }
            return true
            
        case 15: // 'R' (15): Cmd+Opt+R -> Reset
            DispatchQueue.main.async { [weak self] in
                self?.onReset?()
            }
            return true
            
        default:
            return false
        }
    }
}
