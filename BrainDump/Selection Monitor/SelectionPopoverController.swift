import AppKit
import SwiftUI

/// Controller for the selection popover window
final class SelectionPopoverController {
    
    static let shared = SelectionPopoverController()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SelectionPopoverView>?
    private var hideTimer: Timer?
    
    /// Currently displayed text
    private(set) var currentText: String = ""
    
    /// Auto-hide delay
    private let autoHideDelay: TimeInterval = 5.0
    
    private init() {}
    
    // MARK: - Show/Hide
    
    /// Show the popover at the specified position
    func show(at position: NSPoint, withText text: String) {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentText = text
            
            // Cancel any pending hide
            self.hideTimer?.invalidate()
            
            if self.panel == nil {
                self.createPanel()
            }
            
            // Update content
            let contentView = SelectionPopoverView(
                onCapture: { [weak self] in
                    self?.captureAndHide()
                },
                onDismiss: { [weak self] in
                    self?.hide()
                }
            )
            self.hostingView?.rootView = contentView
            
            // Position the panel
            let panelSize = CGSize(width: 120, height: 36)
            
            // Find the screen containing the mouse position
            // NSEvent.mouseLocation uses bottom-left origin (0,0 at bottom-left)
            let mouseLocation = position
            var targetScreen = NSScreen.main
            
            // Find which screen contains the mouse
            for screen in NSScreen.screens {
                if screen.frame.contains(mouseLocation) {
                    targetScreen = screen
                    break
                }
            }
            
            guard let screen = targetScreen else {
                // Fallback: use main screen
                if let mainScreen = NSScreen.main {
                    self.panel?.setFrameOrigin(NSPoint(x: mouseLocation.x, y: mouseLocation.y))
                    self.panel?.orderFront(nil)
                }
                return
            }
            
            // Calculate adjusted position relative to screen frame
            // mouseLocation is already in screen coordinates (bottom-left origin)
            var adjustedX = mouseLocation.x + 15  // Offset to the right of cursor
            var adjustedY = mouseLocation.y + 25   // Offset above cursor
            
            // Ensure popover stays within screen bounds
            let screenFrame = screen.frame
            let minX = screenFrame.minX + 10
            let maxX = screenFrame.maxX - panelSize.width - 10
            let minY = screenFrame.minY + panelSize.height + 10
            let maxY = screenFrame.maxY - 10
            
            adjustedX = max(minX, min(adjustedX, maxX))
            adjustedY = max(minY, min(adjustedY, maxY))
            
            let finalPosition = NSPoint(x: adjustedX, y: adjustedY)
            self.panel?.setFrameOrigin(finalPosition)
            self.panel?.orderFront(nil)
            
            // Bring to front
            self.panel?.orderFrontRegardless()
            
            // Auto-hide after delay
            self.hideTimer = Timer.scheduledTimer(withTimeInterval: self.autoHideDelay, repeats: false) { [weak self] _ in
                self?.hide()
            }
        }
    }
    
    /// Hide the popover
    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.invalidate()
            self?.hideTimer = nil
            self?.panel?.orderOut(nil)
        }
    }
    
    /// Capture the text and hide
    private func captureAndHide() {
        SelectionMonitor.shared.captureSelectedText()
    }
    
    // MARK: - Panel Creation
    
    private func createPanel() {
        let contentView = SelectionPopoverView(
            onCapture: { [weak self] in
                self?.captureAndHide()
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame.size = CGSize(width: 120, height: 36)
        self.hostingView = hostingView
        
        let contentRect = NSRect(x: 0, y: 0, width: 120, height: 36)
        
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating  // Use floating level to ensure visibility above other windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = false  // Ensure it can receive mouse events
        
        panel.contentView = hostingView
        
        self.panel = panel
    }
}

// MARK: - Selection Popover View

struct SelectionPopoverView: View {
    
    let onCapture: () -> Void
    let onDismiss: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Brain icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Capture")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 16, height: 16)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        colors: isHovering ? [.purple.opacity(0.5), .blue.opacity(0.5)] : [.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onCapture()
        }
    }
}

// MARK: - Preview

struct SelectionPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        SelectionPopoverView(onCapture: {}, onDismiss: {})
            .padding(20)
            .background(Color.gray.opacity(0.3))
    }
}



