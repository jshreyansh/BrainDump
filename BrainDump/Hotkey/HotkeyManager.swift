import AppKit
import Carbon

/// Manager for global hotkey registration and handling
final class HotkeyManager {
    
    static let shared = HotkeyManager()
    
    /// The registered hotkey references
    private var hotkeyRefs: [UInt32: EventHotKeyRef] = [:]
    
    /// Hotkey IDs
    enum HotkeyID: UInt32 {
        case capture = 1        // ⌘⌥D - Original capture hotkey
        case textInput = 2      // ⌘⌥[ - Text input
        case partialScreenshot = 3  // ⌘⌥] - Partial screenshot
        case fullScreenshot = 4     // ⌘⌥\ - Full screenshot
    }
    
    /// Signature for all hotkeys
    let hotkeySignature = OSType(0x4244) // "BD" for BrainDump
    
    /// Whether hotkeys are currently registered
    private(set) var isRegistered = false
    
    /// Callback when capture hotkey is triggered
    var onHotkeyPressed: (() -> Void)?
    
    /// Callback when text input hotkey is triggered
    var onTextInputHotkeyPressed: (() -> Void)?
    
    /// Callback when partial screenshot hotkey is triggered
    var onPartialScreenshotHotkeyPressed: (() -> Void)?
    
    /// Callback when full screenshot hotkey is triggered
    var onFullScreenshotHotkeyPressed: (() -> Void)?
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register all global hotkeys
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
        
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        
        // Register all hotkeys
        // 1. Original capture hotkey: ⌘⌥D
        registerHotkey(keyCode: 0x02, modifiers: modifiers, id: .capture, description: "⌘⌥D")
        
        // 2. Text input: ⌘⌥[
        // [ key code = 0x21 (33 decimal)
        registerHotkey(keyCode: 0x21, modifiers: modifiers, id: .textInput, description: "⌘⌥[")
        
        // 3. Partial screenshot: ⌘⌥]
        // ] key code = 0x1E (30 decimal)
        registerHotkey(keyCode: 0x1E, modifiers: modifiers, id: .partialScreenshot, description: "⌘⌥]")
        
        // 4. Full screenshot: ⌘⌥\
        // \ key code = 0x2A (42 decimal)
        registerHotkey(keyCode: 0x2A, modifiers: modifiers, id: .fullScreenshot, description: "⌘⌥\\")
        
        isRegistered = true
    }
    
    /// Register a single hotkey
    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, id: HotkeyID, description: String) {
        let hotkeyID = EventHotKeyID(signature: hotkeySignature, id: id.rawValue)
        var hotkeyRef: EventHotKeyRef?
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        
        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs[id.rawValue] = ref
            print("BrainDump: Global hotkey \(description) registered successfully")
        } else {
            print("BrainDump: Failed to register hotkey \(description), status: \(status)")
        }
    }
    
    /// Unregister all global hotkeys
    func unregister() {
        guard isRegistered else { return }
        
        for (_, hotkeyRef) in hotkeyRefs {
            UnregisterEventHotKey(hotkeyRef)
        }
        
        hotkeyRefs.removeAll()
        isRegistered = false
        print("BrainDump: All global hotkeys unregistered")
    }
    
    // MARK: - Capture Flow
    
    /// Called when hotkey is pressed - initiates the capture flow
    func handleHotkeyPressed() {
        print("BrainDump: Hotkey pressed, initiating capture...")
        
        // Capture the source app BEFORE we do anything else
        // This ensures we get the app the user was in when they pressed the hotkey
        let sourceApp = NSWorkspace.shared.frontmostApplication
        
        // Skip if BrainDump is frontmost (shouldn't happen with global hotkey, but just in case)
        let capturedSourceApp = (sourceApp?.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : sourceApp
        
        if let appName = capturedSourceApp?.localizedName {
            print("BrainDump: Capturing from source app: \(appName)")
        }
        
        // Get current clipboard state
        let previousChangeCount = ClipboardHelper.shared.getClipboardChangeCount()
        
        // Simulate ⌘+C to copy selected content
        guard ClipboardHelper.shared.simulateCopy() else {
            print("BrainDump: Failed to simulate copy")
            return
        }
        
        // Wait briefly for clipboard to update, then check for content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.processClipboardContent(previousChangeCount: previousChangeCount, sourceApp: capturedSourceApp)
        }
    }
    
    private func processClipboardContent(previousChangeCount: Int, sourceApp: NSRunningApplication?) {
        let clipboard = ClipboardHelper.shared
        
        // Check if clipboard changed (new content was copied)
        _ = clipboard.clipboardChanged(since: previousChangeCount)
        
        // Try to save text first
        if let text = clipboard.readText(), !text.isEmpty {
            if StorageManager.shared.saveText(text, method: .hotkey, sourceApp: sourceApp) != nil {
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
        
        // Trigger animation on floating bubble
        NotificationCenter.default.post(name: NSNotification.Name("TriggerSaveAnimation"), object: nil)
        
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
    
    if status == noErr && hotkeyID.signature == manager.hotkeySignature {
        DispatchQueue.main.async {
            if let hotkeyType = HotkeyManager.HotkeyID(rawValue: hotkeyID.id) {
                switch hotkeyType {
                case .capture:
                    manager.handleHotkeyPressed()
                case .textInput:
                    manager.onTextInputHotkeyPressed?()
                case .partialScreenshot:
                    manager.onPartialScreenshotHotkeyPressed?()
                case .fullScreenshot:
                    manager.onFullScreenshotHotkeyPressed?()
                }
            }
        }
    }
    
    return noErr
}
