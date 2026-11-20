import Cocoa
import SwiftUI
import Combine

@main
final class FlowApp: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = FlowApp()
        app.delegate = delegate
        app.run()
    }
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    
    private var statsWindowController: NSWindowController?
    private var preferencesWindowController: NSWindowController?
    private var fullScreenBreakWindowController: NSWindowController?
    
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure dock icon based on settings
        let showDock = AppSettings.shared.showDockIcon
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
        
        // Setup User Notifications
        NotificationManager.shared.setup()
        
        // Setup Status Bar Item
        setupStatusItem()
        
        // Setup Popover
        setupPopover()
        
        // Observe timer changes to update Menu Bar title/icon
        setupTimerObserver()
        
        // Observe break window trigger
        setupBreakWindowObserver()
    }
    
    // MARK: - Status Item Setup
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem.button else { return }
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        
        updateStatusBarDisplay()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 490)
        popover.behavior = .transient
        popover.delegate = self
    }
    
    private func makeHUDViewController() -> NSViewController {
        let hudView = MenuBarHUDView(
            onOpenStats: { [weak self] in
                self?.openStatsWindow()
            },
            onOpenSettings: { [weak self] in
                self?.openPreferencesWindow()
            },
            onOpenFullScreenBreak: { [weak self] in
                self?.openFullScreenBreakWindow()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        return NSHostingController(rootView: hudView)
    }
    
    public func popoverDidClose(_ notification: Notification) {
        // Completely detach and free SwiftUI hosting view when popover is closed
        popover.contentViewController = nil
    }
    
    private func setupTimerObserver() {
        let timer = TimerManager.shared
        
        timer.$timeRemaining
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
            
        timer.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusBarDisplay()
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusBarDisplay() {
        guard let button = statusItem.button else { return }
        
        let timer = TimerManager.shared
        let settings = AppSettings.shared
        let mode = settings.menuBarDisplayMode
        
        let timeStr = timer.formattedTime
        
        var iconName = "timer"
        if let type = timer.state.currentType {
            switch type {
            case .focus:
                iconName = timer.state.isPaused ? "pause.circle.fill" : "bolt.fill"
            case .shortBreak:
                iconName = "cup.and.saucer.fill"
            case .longBreak:
                iconName = "leaf.fill"
            }
        }
        
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Flow")
        image?.isTemplate = true
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        
        switch mode {
        case .iconAndTime:
            button.image = image
            button.imagePosition = .imageLeft
            button.title = " \(timeStr)"
        case .timeOnly:
            button.image = nil
            button.title = timeStr
        case .iconOnly:
            button.image = image
            button.title = ""
        }
    }
    
    // MARK: - Interactions
    
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }
    
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.contentViewController = makeHUDViewController()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        let timer = TimerManager.shared
        
        let playPauseTitle = timer.state.isRunning ? "Pause Session" : (timer.state.isPaused ? "Resume Session" : "Start Focus")
        menu.addItem(NSMenuItem(title: playPauseTitle, action: #selector(contextPlayPause), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Skip to Next Phase", action: #selector(contextSkip), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Reset Session", action: #selector(contextReset), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Focus Analytics & Streaks...", action: #selector(openStatsWindow), keyEquivalent: "a"))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferencesWindow), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Flow", action: #selector(contextQuit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Restore normal click behavior
    }
    
    @objc private func contextPlayPause() {
        TimerManager.shared.togglePlayPause()
    }
    
    @objc private func contextSkip() {
        TimerManager.shared.skipSession()
    }
    
    @objc private func contextReset() {
        TimerManager.shared.resetCurrentSession()
    }
    
    @objc private func contextQuit() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Windows Management
    
    @objc public func openStatsWindow() {
        if let controller = statsWindowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let statsView = StatsDashboardView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Flow Analytics"
        window.contentViewController = NSHostingController(rootView: statsView)
        window.isReleasedWhenClosed = false
        
        statsWindowController = NSWindowController(window: window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func openPreferencesWindow() {
        if let controller = preferencesWindowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let prefView = PreferencesView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Flow Preferences"
        window.contentViewController = NSHostingController(rootView: prefView)
        window.isReleasedWhenClosed = false
        
        preferencesWindowController = NSWindowController(window: window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupBreakWindowObserver() {
        TimerManager.shared.$isFullScreenBreakPresented
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow in
                if shouldShow {
                    self?.openFullScreenBreakWindow()
                } else {
                    self?.closeFullScreenBreakWindow()
                }
            }
            .store(in: &cancellables)
    }
    
    @objc public func openFullScreenBreakWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }
        
        if let controller = fullScreenBreakWindowController, let window = controller.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let breakView = FullScreenBreakView { [weak self] in
            self?.closeFullScreenBreakWindow()
        }
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        let window = BreakModalWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.onDismiss = { [weak self] in
            self?.closeFullScreenBreakWindow()
        }
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        
        let hostingController = NSHostingController(rootView: breakView)
        window.contentViewController = hostingController
        window.setFrame(screenFrame, display: true)
        
        fullScreenBreakWindowController = NSWindowController(window: window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func closeFullScreenBreakWindow() {
        guard fullScreenBreakWindowController != nil else { return }
        fullScreenBreakWindowController?.window?.orderOut(nil)
        fullScreenBreakWindowController = nil
        if TimerManager.shared.isFullScreenBreakPresented {
            TimerManager.shared.isFullScreenBreakPresented = false
        }
    }
}

final class BreakModalWindow: NSWindow {
    var onDismiss: (() -> Void)?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}
