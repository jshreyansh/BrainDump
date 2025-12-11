import AppKit
import Carbon

/// Helper for clipboard operations and simulating key presses
final class ClipboardHelper {
    
    static let shared = ClipboardHelper()
    
    private init() {}
    
    // MARK: - Clipboard Reading
    
    /// Read text from clipboard
    func readText() -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
    
    /// Read image from clipboard
    func readImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        
        // Try to get image directly
        if let image = NSImage(pasteboard: pasteboard) {
            return image
        }
        
        // Try to get from file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            return image
        }
        
        return nil
    }
    
    /// Check if clipboard has text
    func hasText() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string) != nil
    }
    
    /// Check if clipboard has image
    func hasImage() -> Bool {
        let pasteboard = NSPasteboard.general
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff, .pdf]
        return pasteboard.availableType(from: imageTypes) != nil
    }
    
    // MARK: - Simulate Copy (⌘+C)
    
    /// Simulate pressing ⌘+C to copy selected content
    /// Returns true if the operation was initiated successfully
    func simulateCopy() -> Bool {
        // Create key down event for 'C' with Command modifier
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_ANSI_C),
            keyDown: true
        ) else {
            return false
        }
        
        // Add Command modifier
        keyDownEvent.flags = .maskCommand
        
        // Create key up event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_ANSI_C),
            keyDown: false
        ) else {
            return false
        }
        
        keyUpEvent.flags = .maskCommand
        
        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        
        return true
    }
    
    /// Store the current clipboard change count to detect changes
    func getClipboardChangeCount() -> Int {
        return NSPasteboard.general.changeCount
    }
    
    /// Check if clipboard changed since the given change count
    func clipboardChanged(since changeCount: Int) -> Bool {
        return NSPasteboard.general.changeCount != changeCount
    }
}

// MARK: - Virtual Key Codes

/// Common virtual key codes from Carbon
private let kVK_ANSI_C: Int = 0x08
private let kVK_ANSI_D: Int = 0x02



