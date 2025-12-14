import AppKit
import SwiftUI
import QuartzCore

// MARK: - Custom Panel that can become key window

/// A custom NSPanel subclass that can properly receive keyboard input.
/// Standard borderless NSPanel returns false for canBecomeKey, which prevents keyboard input.
final class KeyablePanel: NSPanel {
    
    /// Allow this panel to become the key window (required for keyboard input)
    override var canBecomeKey: Bool {
        return true
    }
    
    /// Don't become main window - we're a floating utility panel
    override var canBecomeMain: Bool {
        return false
    }
}

// MARK: - Custom Hit-Testing View

/// A custom view that only responds to mouse events within the actual content area
/// This prevents the large invisible panel area from blocking mouse events
final class HitTestingView: NSView {
    
    /// The content bounds that should respond to mouse events
    var contentBounds: CGRect = .zero
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Convert point to this view's coordinate system
        let localPoint = convert(point, from: superview)
        
        // Only respond if the point is within the content bounds
        if contentBounds.contains(localPoint) {
            // Check if any subview (like the hosting view) should handle this
            for subview in subviews.reversed() {
                let subviewPoint = convert(point, to: subview)
                if let hitView = subview.hitTest(subviewPoint) {
                    return hitView
                }
            }
            return self
        }
        
        // Return nil to allow mouse events to pass through to windows behind
        return nil
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}

// MARK: - Floating Bubble Controller

/// Controller for the floating bubble window
final class FloatingBubbleController {
    
    private var panel: KeyablePanel?
    private var hostingView: NSHostingView<BubbleWithToast>?
    private var hitTestingView: HitTestingView?
    
    // Panel size constants
    private let pillWidth: CGFloat = 120
    private let pillHeight: CGFloat = 32
    private let collapsedWidth: CGFloat = 130  // Pill width (120) + small padding
    private let collapsedHeight: CGFloat = 42  // Pill height (32) + small padding
    private let expandedWidth: CGFloat = 280
    private let expandedHeight: CGFloat = 330
    
    /// Store the previously active app to restore focus after text input
    /// Also used for capturing source app metadata when saving text
    private(set) var previousActiveApp: NSRunningApplication?
    
    /// Track the last non-BrainDump app that was active
    /// This is updated whenever an app becomes active
    private var lastNonBrainDumpApp: NSRunningApplication?
    
    private var appActivationObserver: NSObjectProtocol?
    
    private init() {
        // Observe app activation changes to track the last non-BrainDump app
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            
            // If another app becomes active and text input is open, close it
            if app.bundleIdentifier != Bundle.main.bundleIdentifier && self.isTextInputMode {
                print("BrainDump: Another app activated while text input is open, closing text input")
                // Post notification to close text input in the view
                NotificationCenter.default.post(name: NSNotification.Name("CloseTextInput"), object: nil)
                // Disable text input mode
                self.disableTextInputMode()
            }
            
            // Track any app that's not BrainDump
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.lastNonBrainDumpApp = app
            }
        }
        
        // Also observe when the panel loses focus (window resigns key)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Check if the resigning window is our panel
            if let window = notification.object as? NSPanel,
               window == self.panel,
               self.isTextInputMode {
                // Small delay to check if another app actually became active
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    // Check if another app is now active (not BrainDump)
                    if let frontApp = NSWorkspace.shared.frontmostApplication,
                       frontApp.bundleIdentifier != Bundle.main.bundleIdentifier,
                       self.isTextInputMode {
                        print("BrainDump: Panel lost focus to another app (\(frontApp.localizedName ?? "unknown")), closing text input")
                        NotificationCenter.default.post(name: NSNotification.Name("CloseTextInput"), object: nil)
                        self.disableTextInputMode()
                    }
                }
            }
        }
        
        // Initialize with current frontmost app if it's not BrainDump
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastNonBrainDumpApp = frontApp
        }
    }
    
    deinit {
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    /// Capture the current frontmost app (before BrainDump becomes active)
    /// This should be called when the user initiates text input, before enabling text input mode
    func capturePreviousActiveApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            // Fallback to last known non-BrainDump app
            previousActiveApp = lastNonBrainDumpApp
            if let app = lastNonBrainDumpApp {
                print("BrainDump: Captured previous app (fallback): \(app.localizedName ?? "unknown")")
            }
            return
        }
        
        // If BrainDump is frontmost, use the last tracked non-BrainDump app
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            previousActiveApp = lastNonBrainDumpApp
            if let app = lastNonBrainDumpApp {
                print("BrainDump: Captured previous app (BrainDump was frontmost): \(app.localizedName ?? "unknown")")
            } else {
                print("BrainDump: ⚠️ BrainDump is frontmost but no previous app tracked")
            }
        } else {
            // BrainDump is not frontmost, so capture the current app
            previousActiveApp = frontApp
            // Also update our tracking
            lastNonBrainDumpApp = frontApp
            print("BrainDump: Captured previous app: \(frontApp.localizedName ?? "unknown")")
        }
    }
    
    /// Shared instance
    static let shared = FloatingBubbleController()
    
    /// Whether the bubble is currently visible
    var isVisible: Bool {
        panel?.isVisible ?? false
    }
    
    /// Whether text input mode is active
    private(set) var isTextInputMode = false
    
    // MARK: - Public Methods
    
    /// Show the floating bubble
    func show() {
        if panel == nil {
            createPanel()
        }
        
        panel?.orderFront(nil)
    }
    
    /// Hide the floating bubble
    func hide() {
        panel?.orderOut(nil)
    }
    
    /// Toggle visibility
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    /// Show toast notification (called after hotkey capture)
    func showSaveToast() {
        ToastManager.shared.show()
    }
    
    // MARK: - Hotkey Actions
    
    /// Trigger text input mode via hotkey
    func triggerTextInput() {
        capturePreviousActiveApp()
        NotificationCenter.default.post(name: NSNotification.Name("TriggerTextInput"), object: nil)
    }
    
    /// Trigger partial screenshot via hotkey
    func triggerPartialScreenshot() {
        NotificationCenter.default.post(name: NSNotification.Name("TriggerPartialScreenshot"), object: nil)
    }
    
    /// Trigger full screenshot via hotkey
    func triggerFullScreenshot() {
        NotificationCenter.default.post(name: NSNotification.Name("TriggerFullScreenshot"), object: nil)
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        // Create content with toast capability
        let contentView = BubbleWithToast()
        
        // Start with collapsed size (pill shape)
        let panelWidth = collapsedWidth
        let panelHeight = collapsedHeight
        
        // Create hit-testing wrapper view
        let hitTestingView = HitTestingView()
        hitTestingView.frame = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        // Initial state is collapsed, so only pill area should respond to hits
        let pillX = (panelWidth - pillWidth) / 2
        let pillY = (panelHeight - pillHeight) / 2
        hitTestingView.contentBounds = NSRect(
            x: pillX,
            y: pillY,
            width: pillWidth,
            height: pillHeight
        )
        self.hitTestingView = hitTestingView
        
        // Create hosting view with expanded size to accommodate all states
        // The hosting view is larger than the panel when collapsed, but that's OK
        // because hit-testing will only respond to the visible area
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame.size = CGSize(width: expandedWidth, height: expandedHeight)
        self.hostingView = hostingView
        
        // Add hosting view to hit-testing view, centered
        hitTestingView.addSubview(hostingView)
        hostingView.frame.origin = CGPoint(x: (panelWidth - expandedWidth) / 2, y: (panelHeight - expandedHeight) / 2)
        
        // Calculate initial position (center top, 20px inset from top)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let inset: CGFloat = 20
        
        // Position so the bubble (center of panel) is at center top
        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.maxY - inset - panelHeight / 2
        
        let contentRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)
        
        // Create KeyablePanel with borderless style
        // Using our custom KeyablePanel that overrides canBecomeKey to return true
        // This is essential for receiving keyboard input in a borderless panel
        let panel = KeyablePanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Configure panel properties for floating behavior
        panel.level = .floating
        // canJoinAllSpaces: visible on all spaces
        // fullScreenAuxiliary: can appear over fullscreen apps
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        // Enable mouse events but use hit-testing to filter them
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        
        // Set content view
        panel.contentView = hitTestingView
        
        self.panel = panel
    }
    
    // MARK: - Dynamic Resizing
    
    /// Update panel size based on expanded/collapsed state
    func updatePanelSize(isExpanded: Bool, showTextInput: Bool) {
        guard let panel = panel, let hitTestingView = hitTestingView, let hostingView = hostingView else { return }
        
        // Determine target size
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        
        if showTextInput {
            // Text input needs more space
            targetWidth = expandedWidth
            targetHeight = expandedHeight
        } else if isExpanded {
            // Expanded state needs space for action buttons
            targetWidth = expandedWidth
            targetHeight = expandedHeight
        } else {
            // Collapsed state - just pill size
            targetWidth = collapsedWidth
            targetHeight = collapsedHeight
        }
        
        // Get current frame
        let currentFrame = panel.frame
        let centerX = currentFrame.midX
        let centerY = currentFrame.midY
        
        // Calculate new frame (centered on current position)
        let newFrame = NSRect(
            x: centerX - targetWidth / 2,
            y: centerY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        
        // Update hit-testing view bounds
        hitTestingView.frame = NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        
        // Set content bounds based on state
        // When collapsed, only the pill area should respond to hits
        // When expanded, the entire panel should respond
        if showTextInput || isExpanded {
            hitTestingView.contentBounds = NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        } else {
            // Collapsed: only the pill area (centered in the panel)
            let pillX = (targetWidth - pillWidth) / 2
            let pillY = (targetHeight - pillHeight) / 2
            hitTestingView.contentBounds = NSRect(
                x: pillX,
                y: pillY,
                width: pillWidth,
                height: pillHeight
            )
        }
        
        // Update hosting view position (centered in hit-testing view)
        hostingView.frame.origin = CGPoint(
            x: (targetWidth - expandedWidth) / 2,
            y: (targetHeight - expandedHeight) / 2
        )
        
        // Resize panel without animation - SwiftUI handles the visual transitions
        // This prevents the bouncing effect and keeps the bubble visually in place
        panel.setFrame(newFrame, display: true, animate: false)
    }
    
    // MARK: - Position Management
    
    /// Reset position to default (center top)
    func resetPosition() {
        guard let panel = panel else { return }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let inset: CGFloat = 20
        
        let panelX = screenFrame.midX - panel.frame.width / 2
        let panelY = screenFrame.maxY - inset - panel.frame.height / 2
        
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }
    
    // MARK: - Text Input Mode
    
    /// Enable text input mode - makes panel accept keyboard input
    /// This properly activates the app to receive keyboard events
    /// Note: previousActiveApp should already be captured via capturePreviousActiveApp()
    /// before calling this method
    func enableTextInputMode() {
        guard let panel = panel else { return }
        isTextInputMode = true
        
        // previousActiveApp should already be set by capturePreviousActiveApp()
        // If not set, try to capture it now (fallback)
        if previousActiveApp == nil {
            capturePreviousActiveApp()
        }
        
        // Remove nonactivatingPanel to allow keyboard input
        if panel.styleMask.contains(.nonactivatingPanel) {
            panel.styleMask.remove(.nonactivatingPanel)
        }
        
        // Make sure it can become key
        panel.becomesKeyOnlyIfNeeded = false
        
        // CRITICAL: We MUST activate the app to receive keyboard input
        // Using ignoringOtherApps: false is gentler and less likely to cause issues
        // The panel's collectionBehavior helps prevent space switching
        NSApp.activate(ignoringOtherApps: true)
        
        // Make the panel key window
        panel.makeKeyAndOrderFront(nil)
    }
    
    /// Disable text input mode - restores non-activating behavior and previous app focus
    func disableTextInputMode() {
        guard let panel = panel else { return }
        isTextInputMode = false
        
        // Restore nonactivatingPanel style
        if !panel.styleMask.contains(.nonactivatingPanel) {
            panel.styleMask.insert(.nonactivatingPanel)
        }
        
        panel.becomesKeyOnlyIfNeeded = true
        panel.resignKey()
        
        // Restore focus to the previously active app
        // This provides a seamless experience - user can quickly jot a note
        // and return to what they were doing
        if let previousApp = previousActiveApp {
            previousApp.activate()
            previousActiveApp = nil
        }
    }
    
    /// Make the panel key window (for text input)
    func makeKey() {
        panel?.makeKey()
    }
    
    /// Resign key window
    func resignKey() {
        panel?.resignKey()
    }
}

// MARK: - SwiftUI Environment Key

struct FloatingBubbleControllerKey: EnvironmentKey {
    static let defaultValue = FloatingBubbleController.shared
}

extension EnvironmentValues {
    var floatingBubbleController: FloatingBubbleController {
        get { self[FloatingBubbleControllerKey.self] }
        set { self[FloatingBubbleControllerKey.self] = newValue }
    }
}
