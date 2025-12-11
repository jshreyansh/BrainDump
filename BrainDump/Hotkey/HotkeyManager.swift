import AppKit
import Carbon

/// Manager for global hotkey registration and handling
final class HotkeyManager {
    
    static let shared = HotkeyManager()
    
    /// The registered hotkey reference
    private var hotkeyRef: EventHotKeyRef?
    
    /// Unique hotkey ID
    let hotkeyID = EventHotKeyID(signature: OSType(0x4244), id: 1) // "BD" for BrainDump
    
    /// Whether the hotkey is currently registered
    private(set) var isRegistered = false
    
    /// Callback when hotkey is triggered
    var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register the global hotkey (⌘ + ⌥ + D)
    func register() {
        guard !isRegistered else { return }
        
        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
        
        // Register hotkey: ⌘ + ⌥ + D
        // D key = 0x02
        // Command = cmdKey (256)
        // Option = optionKey (2048)
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = 0x02 // D key
        
        let hotkeyID = self.hotkeyID
        var hotkeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr {
            self.hotkeyRef = hotkeyRef
            isRegistered = true
            print("BrainDump: Global hotkey ⌘⌥D registered successfully")
        } else {
            print("BrainDump: Failed to register global hotkey, status: \(status)")
        }
    }
    
    /// Unregister the global hotkey
    func unregister() {
        guard isRegistered, let hotkeyRef = hotkeyRef else { return }
        
        UnregisterEventHotKey(hotkeyRef)
        self.hotkeyRef = nil
        isRegistered = false
        print("BrainDump: Global hotkey unregistered")
    }
    
    // MARK: - Capture Flow
    
    /// Called when hotkey is pressed - initiates the capture flow
    func handleHotkeyPressed() {
        print("BrainDump: Hotkey pressed, initiating capture...")
        
        // Get current clipboard state
        let previousChangeCount = ClipboardHelper.shared.getClipboardChangeCount()
        
        // Simulate ⌘+C to copy selected content
        guard ClipboardHelper.shared.simulateCopy() else {
            print("BrainDump: Failed to simulate copy")
            return
        }
        
        // Wait briefly for clipboard to update, then check for content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.processClipboardContent(previousChangeCount: previousChangeCount)
        }
    }
    
    private func processClipboardContent(previousChangeCount: Int) {
        let clipboard = ClipboardHelper.shared
        
        // Check if clipboard changed (new content was copied)
        _ = clipboard.clipboardChanged(since: previousChangeCount)
        
        // Try to save text first
        if let text = clipboard.readText(), !text.isEmpty {
            if StorageManager.shared.saveText(text, method: .hotkey) != nil {
                print("BrainDump: Text saved successfully via hotkey")
                showSaveConfirmation()
                return
            }
        }
        
        // Try to save image
        if let image = clipboard.readImage() {
            if StorageManager.shared.saveImage(image, method: .hotkey) != nil {
                print("BrainDump: Image saved successfully via hotkey")
                showSaveConfirmation()
                return
            }
        }
        
        print("BrainDump: No content to capture")
    }
    
    private func showSaveConfirmation() {
        // Show toast via floating bubble
        FloatingBubbleController.shared.showSaveToast()
        
        // Notify callback
        onHotkeyPressed?()
    }
    
    // MARK: - Accessibility Permission
    
    /// Check if accessibility permission is granted
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// Request accessibility permission
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Carbon Event Handler

/// Global event handler function for Carbon hotkey events
private func hotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    
    guard let userData = userData else {
        return OSStatus(eventNotHandledErr)
    }
    
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    
    if status == noErr && hotkeyID.id == manager.hotkeyID.id {
        DispatchQueue.main.async {
            manager.handleHotkeyPressed()
        }
    }
    
    return noErr
}
