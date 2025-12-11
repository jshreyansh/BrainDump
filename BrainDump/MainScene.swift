import SwiftUI

struct MainScene: Scene {
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            // About command
            AboutCommand()
            
            // Sidebar toggle
            SidebarCommands()
            
            // BrainDump-specific commands
            BrainDumpCommands()
            
            // Remove "New Window" from File menu
            CommandGroup(replacing: .newItem, addition: { })
        }
        
        Settings {
            SettingsWindow()
        }
    }
}

// MARK: - BrainDump Commands

struct BrainDumpCommands: Commands {
    
    var body: some Commands {
        CommandMenu("Capture") {
            Button("Capture from Clipboard") {
                captureFromClipboard()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Toggle Floating Bubble") {
                FloatingBubbleController.shared.toggle()
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])
            
            Button("Reset Bubble Position") {
                FloatingBubbleController.shared.resetPosition()
            }
        }
        
        CommandGroup(after: .windowArrangement) {
            Divider()
            
            Button("Open Storage Folder") {
                NSWorkspace.shared.open(StorageManager.shared.storageURL)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }
    }
    
    private func captureFromClipboard() {
        let clipboard = ClipboardHelper.shared
        
        if let text = clipboard.readText(), !text.isEmpty {
            if StorageManager.shared.saveText(text) != nil {
                FloatingBubbleController.shared.showSaveToast()
            }
            return
        }
        
        if let image = clipboard.readImage() {
            if StorageManager.shared.saveImage(image) != nil {
                FloatingBubbleController.shared.showSaveToast()
            }
        }
    }
}
