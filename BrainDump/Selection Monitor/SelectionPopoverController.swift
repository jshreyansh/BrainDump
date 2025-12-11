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
        currentText = text
        
        // Cancel any pending hide
        hideTimer?.invalidate()
        
        if panel == nil {
            createPanel()
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
        hostingView?.rootView = contentView
        
        // Position the panel
        let panelSize = CGSize(width: 120, height: 36)
        
        // Adjust position to keep on screen
        var adjustedPosition = position
        if let screen = NSScreen.main {
            // Keep within horizontal bounds
            adjustedPosition.x = max(10, min(adjustedPosition.x - panelSize.width / 2, screen.frame.width - panelSize.width - 10))
            // Keep within vertical bounds
            adjustedPosition.y = max(panelSize.height + 10, min(adjustedPosition.y, screen.frame.height - 10))
        }
        
        panel?.setFrameOrigin(adjustedPosition)
        panel?.orderFront(nil)
        
        // Auto-hide after delay
        hideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
    
    /// Hide the popover
    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        panel?.orderOut(nil)
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
        
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        
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



