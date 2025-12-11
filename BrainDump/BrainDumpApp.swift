import SwiftUI

@main
struct BrainDumpApp: App {
    
    /// Legacy app delegate for initialization
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MainScene()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuBarButton: MenuBarButton?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize menu bar button
        menuBarButton = MenuBarButton()
        
        // Show floating bubble
        FloatingBubbleController.shared.show()
        
        // Check and request accessibility permission for hotkey
        if HotkeyManager.checkAccessibilityPermission() {
            // Register global hotkey
            HotkeyManager.shared.register()
            
            // Start selection monitoring (requires accessibility permission)
            SelectionMonitor.shared.startMonitoring()
        } else {
            // Request permission - user will see system dialog
            print("BrainDump: Accessibility permission required for global hotkey and selection monitoring")
            // Still try to register in case permission is already granted
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                HotkeyManager.shared.register()
                SelectionMonitor.shared.startMonitoring()
            }
        }
        
        // Initialize storage
        _ = StorageManager.shared
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Unregister hotkey on quit
        HotkeyManager.shared.unregister()
        // Stop selection monitoring
        SelectionMonitor.shared.stopMonitoring()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running even when main window is closed
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen main window when clicking dock icon
        if !flag {
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(self)
                    return true
                }
            }
        }
        return true
    }
}
