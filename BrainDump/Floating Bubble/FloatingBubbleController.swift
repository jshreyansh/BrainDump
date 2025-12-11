import AppKit
import SwiftUI

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

// MARK: - Floating Bubble Controller

/// Controller for the floating bubble window
final class FloatingBubbleController {
    
    private var panel: KeyablePanel?
    private var hostingView: NSHostingView<BubbleWithToast>?
    
    /// Store the previously active app to restore focus after text input
    private var previousActiveApp: NSRunningApplication?
    
    /// Shared instance
    static let shared = FloatingBubbleController()
    
    /// Whether the bubble is currently visible
    var isVisible: Bool {
        panel?.isVisible ?? false
    }
    
    /// Whether text input mode is active
    private(set) var isTextInputMode = false
    
    private init() {}
    
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
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        // Create content with toast capability
        let contentView = BubbleWithToast()
        
        // Larger frame to accommodate expanded actions (3 buttons) and text input
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 330
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame.size = CGSize(width: panelWidth, height: panelHeight)
        self.hostingView = hostingView
        
        // Calculate initial position (bottom-right, 20px inset)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let inset: CGFloat = 20
        
        // Position so the bubble (center of panel) is in bottom-right
        let panelX = screenFrame.maxX - panelWidth / 2 - 40 - inset
        let panelY = screenFrame.minY + inset - panelHeight / 2 + 40
        
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
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        
        // Set content view
        panel.contentView = hostingView
        
        self.panel = panel
    }
    
    // MARK: - Position Management
    
    /// Reset position to default (bottom-right)
    func resetPosition() {
        guard let panel = panel else { return }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let inset: CGFloat = 20
        
        let panelX = screenFrame.maxX - panel.frame.width / 2 - 40 - inset
        let panelY = screenFrame.minY + inset - panel.frame.height / 2 + 40
        
        panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }
    
    // MARK: - Text Input Mode
    
    /// Enable text input mode - makes panel accept keyboard input
    /// This properly activates the app to receive keyboard events
    func enableTextInputMode() {
        guard let panel = panel else { return }
        isTextInputMode = true
        
        // Store the currently active app so we can restore it later
        previousActiveApp = NSWorkspace.shared.frontmostApplication
        
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
