import AppKit
import ApplicationServices
import os.log

/// Logger for selection monitor
private let logger = Logger(subsystem: "com.braindump", category: "SelectionMonitor")

/// Monitors text selection across all applications and shows a capture button
final class SelectionMonitor {
    
    static let shared = SelectionMonitor()
    
    /// Whether selection monitoring is active
    private(set) var isMonitoring = false
    
    /// Timer for polling selection changes
    private var pollTimer: Timer?
    
    /// Last known selected text to avoid duplicate popups
    private var lastSelectedText: String?
    
    /// Minimum selection length to trigger popup
    private let minimumSelectionLength = 3
    
    /// Debounce delay after selection
    private let debounceDelay: TimeInterval = 0.4
    
    /// Work item for debouncing
    private var debounceWorkItem: DispatchWorkItem?
    
    /// Global mouse event monitor
    private var mouseMonitor: Any?
    
    /// Debug log file in user's home
    private let logFileURL: URL
    
    /// Enabled state from settings
    var isEnabled: Bool {
        get { 
            let value = UserDefaults.standard.object(forKey: "settings.selection.enabled")
            return value as? Bool ?? true
        }
        set { 
            UserDefaults.standard.set(newValue, forKey: "settings.selection.enabled") 
        }
    }
    
    private init() {
        // Setup log file in Desktop for easy access
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        logFileURL = desktop.appendingPathComponent("BrainDump_SelectionMonitor.log")
        
        // Clear old log
        try? FileManager.default.removeItem(at: logFileURL)
        
        log("========================================")
        log("SelectionMonitor INITIALIZED")
        log("isEnabled = \(isEnabled)")
        log("Log file: \(logFileURL.path)")
        log("========================================")
    }
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // System log
        NSLog("BrainDump SelectionMonitor: %@", message)
        
        // File log
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
    
    // MARK: - Start/Stop Monitoring
    
    /// Start monitoring text selections
    func startMonitoring() {
        log("startMonitoring() CALLED")
        log("  - isMonitoring: \(isMonitoring)")
        log("  - isEnabled: \(isEnabled)")
        
        guard !isMonitoring else { 
            log("  Already monitoring, skipping")
            return 
        }
        
        guard isEnabled else {
            log("  Selection monitoring DISABLED in settings")
            return
        }
        
        // Check accessibility permission
        let hasPermission = AXIsProcessTrusted()
        log("  - AXIsProcessTrusted: \(hasPermission)")
        
        guard hasPermission else {
            log("  NO accessibility permission - will request")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }
        
        isMonitoring = true
        
        // Create and schedule timer
        log("  Creating poll timer...")
        pollTimer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkForSelection()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
        log("  Timer scheduled on main RunLoop")
        
        // Monitor mouse up events
        log("  Adding global mouse monitor...")
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.checkForSelection()
            }
        }
        log("  Mouse monitor added")
        
        log("✅ Selection monitoring STARTED SUCCESSFULLY")
        log("  - Log file: \(logFileURL.path)")
    }
    
    /// Stop monitoring text selections
    func stopMonitoring() {
        log("stopMonitoring() called")
        isMonitoring = false
        pollTimer?.invalidate()
        pollTimer = nil
        debounceWorkItem?.cancel()
        
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        
        SelectionPopoverController.shared.hide()
        lastSelectedText = nil
        log("Selection monitoring STOPPED")
    }
    
    /// Toggle monitoring based on settings
    func updateMonitoringState() {
        log("updateMonitoringState() - isEnabled=\(isEnabled), isMonitoring=\(isMonitoring)")
        if isEnabled && !isMonitoring {
            startMonitoring()
        } else if !isEnabled && isMonitoring {
            stopMonitoring()
        }
    }
    
    // MARK: - Selection Detection
    
    private var checkCount = 0
    
    private func checkForSelection() {
        guard isMonitoring && isEnabled else { return }
        
        checkCount += 1
        
        // Get the frontmost app
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return
        }
        
        // Skip if BrainDump is frontmost
        if focusedApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        
        let pid = focusedApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get the focused UI element
        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement, 
            kAXFocusedUIElementAttribute as CFString, 
            &focusedElementRef
        )
        
        guard focusedResult == .success, focusedElementRef != nil else {
            return
        }
        
        let focusedElement = focusedElementRef as! AXUIElement
        
        // Try to get selected text
        var selectedTextRef: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            focusedElement, 
            kAXSelectedTextAttribute as CFString, 
            &selectedTextRef
        )
        
        // Log status every 20 checks
        if checkCount % 20 == 0 {
            log("Check #\(checkCount): app=\(focusedApp.localizedName ?? "?"), result=\(textResult.rawValue)")
        }
        
        guard textResult == .success,
              let text = selectedTextRef as? String,
              !text.isEmpty else {
            // No selection - hide popover if needed
            if lastSelectedText != nil {
                lastSelectedText = nil
                DispatchQueue.main.async {
                    SelectionPopoverController.shared.hide()
                }
            }
            return
        }
        
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedText.count >= minimumSelectionLength else {
            return
        }
        
        // Check if this is a new selection
        guard trimmedText != lastSelectedText else { return }
        
        log("📝 NEW SELECTION DETECTED!")
        log("   App: \(focusedApp.localizedName ?? "unknown")")
        log("   Text: \"\(trimmedText.prefix(80))...\"")
        log("   Length: \(trimmedText.count) chars")
        
        lastSelectedText = trimmedText
        
        // Debounce popup
        debounceWorkItem?.cancel()
        debounceWorkItem = DispatchWorkItem { [weak self] in
            self?.showPopoverNearMouse(text: trimmedText)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceDelay, execute: debounceWorkItem!)
    }
    
    private func showPopoverNearMouse(text: String) {
        let mouseLocation = NSEvent.mouseLocation
        
        var popoverPosition = mouseLocation
        popoverPosition.y += 25
        popoverPosition.x += 15
        
        log("🎯 SHOWING POPOVER at (\(Int(popoverPosition.x)), \(Int(popoverPosition.y)))")
        
        SelectionPopoverController.shared.show(at: popoverPosition, withText: text)
    }
    
    // MARK: - Capture
    
    func captureSelectedText() {
        guard let text = lastSelectedText, !text.isEmpty else {
            log("captureSelectedText: No text")
            return
        }
        
        log("💾 CAPTURING: \"\(text.prefix(50))...\"")
        
        if StorageManager.shared.saveText(text, method: .selection) != nil {
            log("✅ Text SAVED via selection")
            ToastManager.shared.show()
            SelectionPopoverController.shared.hide()
            lastSelectedText = nil
        } else {
            log("❌ Save FAILED")
        }
    }
    
    func getLogFilePath() -> String {
        return logFileURL.path
    }
}
