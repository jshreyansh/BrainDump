import AppKit
import SwiftUI

class MenuBarButton {
    
    let statusItem: NSStatusItem
    
    init() {
        statusItem = NSStatusBar.system
            .statusItem(withLength: CGFloat(NSStatusItem.squareLength))
                
        guard let button = statusItem.button else {
            return
        }
        
        // Load custom logo image from bundle
        if let imagePath = Bundle.main.path(forResource: "braindumplogowhiteapp", ofType: "png"),
           let image = NSImage(contentsOfFile: imagePath) {
            // Configure image for menu bar
            // Since it's a white logo, we keep isTemplate = false to show it as-is
            image.isTemplate = false
            // Set appropriate size for menu bar (18x18 is standard, but we'll let it scale)
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            // Fallback to system symbol if image not found
            print("MenuBarButton: Could not load braindumplogowhiteapp.png, using system symbol")
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "BrainDump")
        }
        
        button.imagePosition = NSControl.ImagePosition.imageOnly
        button.target = self
        button.action = #selector(showMenu(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    
    // MARK: - Show Menu
    
    @objc
    func showMenu(_ sender: AnyObject?) {
        switch NSApp.currentEvent?.type {
        case .leftMouseUp:
            showPrimaryMenu()
        case .rightMouseUp:
            showSecondaryMenu()
        default:
            break
        }
    }
    
    func showPrimaryMenu() {
        let menu = NSMenu()
        
        // Quick capture section
        addItem("Capture from Clipboard", action: #selector(captureFromClipboard), key: "v", modifiers: [.command, .shift], to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        // Bubble controls
        let bubbleItem = NSMenuItem()
        bubbleItem.title = FloatingBubbleController.shared.isVisible ? "Hide Floating Bubble" : "Show Floating Bubble"
        bubbleItem.target = self
        bubbleItem.action = #selector(toggleBubble)
        bubbleItem.keyEquivalent = "b"
        bubbleItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(bubbleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Open main window
        addItem("Open BrainDump", action: #selector(openMainWindow), key: "o", to: menu)
        addItem("Open Storage Folder", action: #selector(openStorageFolder), key: "", to: menu)
        
        menu.addItem(NSMenuItem.separator())
        
        addItem("About BrainDump", action: #selector(showAbout), key: "", to: menu)
        addItem("Quit", action: #selector(quit), key: "q", to: menu)
        
        showStatusItemMenu(menu)
    }
        
    func showSecondaryMenu() {
        let menu = NSMenu()
        addItem("About BrainDump", action: #selector(showAbout), key: "", to: menu)
        menu.addItem(NSMenuItem.separator())
        addItem("Quit", action: #selector(quit), key: "q", to: menu)
        showStatusItemMenu(menu)
    }
    
    private func showStatusItemMenu(_ menu: NSMenu) {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
    
    private func addItem(_ title: String, action: Selector?, key: String, modifiers: NSEvent.ModifierFlags = .command, to menu: NSMenu) {
        let item = NSMenuItem()
        item.title = title
        item.target = self
        item.action = action
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
    }
    
    // MARK: - Actions
    
    @objc
    func captureFromClipboard() {
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
    
    @objc
    func toggleBubble() {
        FloatingBubbleController.shared.toggle()
    }
    
    @objc
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            if window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
    
    @objc
    func openStorageFolder() {
        NSWorkspace.shared.open(StorageManager.shared.storageURL)
    }
    
    @objc
    func showAbout() {
        AboutWindow.show()
    }
    
    @objc
    func quit() {
        NSApp.terminate(self)
    }
}
