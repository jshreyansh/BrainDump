import SwiftUI

struct MenuBarPopup: View {
        
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("BrainDump")
                    .font(.headline)
            }
            
            Divider()
            
            // Quick Actions
            VStack(spacing: 8) {
                Button {
                    captureFromClipboard()
                } label: {
                    Label("Capture Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                
                Button {
                    FloatingBubbleController.shared.toggle()
                } label: {
                    Label(
                        FloatingBubbleController.shared.isVisible ? "Hide Bubble" : "Show Bubble",
                        systemImage: "bubble.right"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Footer
            HStack {
                Text("⌘⌥D to capture")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Open") {
                    openMainWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 220)
    }
    
    private func captureFromClipboard() {
        let clipboard = ClipboardHelper.shared
        
        if let text = clipboard.readText(), !text.isEmpty {
            if StorageManager.shared.saveText(text, method: .clipboard) != nil {
                FloatingBubbleController.shared.showSaveToast()
            }
            return
        }
        
        if let image = clipboard.readImage() {
            if StorageManager.shared.saveImage(image, method: .clipboard) != nil {
                FloatingBubbleController.shared.showSaveToast()
            }
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
}

struct MenuBarPopup_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarPopup()
    }
}
