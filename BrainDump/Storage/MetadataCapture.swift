import Foundation
import AppKit
import NaturalLanguage
import ApplicationServices

/// Helper class to capture metadata at the moment of capture
final class MetadataCapture {
    
    static let shared = MetadataCapture()
    
    private init() {}
    
    // MARK: - Main Capture Methods
    
    /// Capture metadata for a text capture
    /// - Parameters:
    ///   - text: The text content to capture
    ///   - method: The capture method used
    ///   - sourceApp: Optional source app to use (useful when BrainDump is frontmost, e.g., during floating widget text input)
    func captureForText(_ text: String, method: CaptureMetadata.CaptureMethod, sourceApp: NSRunningApplication? = nil) -> CaptureMetadata {
        let appInfo = captureSourceAppInfo(sourceApp: sourceApp)
        let textAnalysis = analyzeText(text)
        let deviceInfo = captureDeviceInfo()
        
        // Extract URL if from browser
        let browserURL = extractBrowserURL(from: appInfo.bundleId)
        let domain = browserURL.flatMap { extractDomain(from: $0) }
        
        // Generate auto tags
        var tags = generateAutoTags(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            windowTitle: appInfo.windowTitle,
            hasUrls: !(textAnalysis.detectedUrls ?? []).isEmpty,
            method: method
        )
        
        return CaptureMetadata(
            capturedAt: Date(),
            timezone: TimeZone.current.identifier,
            captureMethod: method,
            sourceAppName: appInfo.name,
            sourceAppBundleId: appInfo.bundleId,
            windowTitle: appInfo.windowTitle,
            url: browserURL,
            domain: domain,
            charCount: textAnalysis.charCount,
            wordCount: textAnalysis.wordCount,
            language: textAnalysis.language,
            detectedUrls: textAnalysis.detectedUrls,
            imageWidth: nil,
            imageHeight: nil,
            deviceName: deviceInfo.name,
            osVersion: deviceInfo.osVersion,
            autoTags: tags
        )
    }
    
    /// Capture metadata for an image capture
    func captureForImage(_ image: NSImage, method: CaptureMetadata.CaptureMethod) -> CaptureMetadata {
        let appInfo = captureSourceAppInfo()
        let deviceInfo = captureDeviceInfo()
        
        // Get image dimensions
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Generate auto tags
        var tags = generateAutoTags(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            windowTitle: appInfo.windowTitle,
            hasUrls: false,
            method: method
        )
        tags.append("image")
        
        // Add resolution category tag
        if width >= 1920 || height >= 1080 {
            tags.append("hd")
        }
        
        return CaptureMetadata(
            capturedAt: Date(),
            timezone: TimeZone.current.identifier,
            captureMethod: method,
            sourceAppName: appInfo.name,
            sourceAppBundleId: appInfo.bundleId,
            windowTitle: appInfo.windowTitle,
            url: nil,
            domain: nil,
            charCount: nil,
            wordCount: nil,
            language: nil,
            detectedUrls: nil,
            imageWidth: width,
            imageHeight: height,
            deviceName: deviceInfo.name,
            osVersion: deviceInfo.osVersion,
            autoTags: tags
        )
    }
    
    // MARK: - Source App Info
    
    private struct AppInfo {
        let name: String?
        let bundleId: String?
        let windowTitle: String?
    }
    
    private func captureSourceAppInfo(sourceApp: NSRunningApplication? = nil) -> AppInfo {
        // If a source app is provided (e.g., from floating widget), use it
        if let providedApp = sourceApp {
            let name = providedApp.localizedName
            let bundleId = providedApp.bundleIdentifier
            let windowTitle = getWindowTitle(for: providedApp)
            return AppInfo(name: name, bundleId: bundleId, windowTitle: windowTitle)
        }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return AppInfo(name: nil, bundleId: nil, windowTitle: nil)
        }
        
        // Skip if BrainDump is frontmost (happens during bubble text input)
        if frontApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            // No source app provided and BrainDump is frontmost
            return AppInfo(name: nil, bundleId: nil, windowTitle: nil)
        }
        
        let name = frontApp.localizedName
        let bundleId = frontApp.bundleIdentifier
        let windowTitle = getWindowTitle(for: frontApp)
        
        return AppInfo(name: name, bundleId: bundleId, windowTitle: windowTitle)
    }
    
    /// Get window title using Accessibility API
    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        // Get focused window
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        
        guard result == .success, let window = windowRef else {
            return nil
        }
        
        // Get window title
        var titleRef: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        
        guard titleResult == .success, let title = titleRef as? String else {
            return nil
        }
        
        return title.isEmpty ? nil : title
    }
    
    // MARK: - Browser URL Extraction
    
    /// Try to extract URL from browser using AppleScript
    private func extractBrowserURL(from bundleId: String?) -> String? {
        guard let bundleId = bundleId else { return nil }
        
        let browserBundleIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.brave.Browser",
            "com.operasoftware.Opera",
            "company.thebrowser.Browser" // Arc
        ]
        
        guard browserBundleIds.contains(bundleId) else { return nil }
        
        var script: String
        
        switch bundleId {
        case "com.apple.Safari":
            script = "tell application \"Safari\" to get URL of current tab of front window"
        case "com.google.Chrome":
            script = "tell application \"Google Chrome\" to get URL of active tab of front window"
        case "com.microsoft.edgemac":
            script = "tell application \"Microsoft Edge\" to get URL of active tab of front window"
        case "org.mozilla.firefox":
            // Firefox doesn't support this well via AppleScript
            return nil
        case "com.brave.Browser":
            script = "tell application \"Brave Browser\" to get URL of active tab of front window"
        case "company.thebrowser.Browser":
            script = "tell application \"Arc\" to get URL of active tab of front window"
        default:
            return nil
        }
        
        // Execute AppleScript
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil, let url = output.stringValue {
                return url
            }
        }
        
        return nil
    }
    
    /// Extract domain from URL
    private func extractDomain(from urlString: String) -> String? {
        guard let url = URL(string: urlString), let host = url.host else {
            return nil
        }
        
        // Remove www. prefix
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
    
    // MARK: - Text Analysis
    
    private struct TextAnalysis {
        let charCount: Int
        let wordCount: Int
        let language: String?
        let detectedUrls: [String]?
    }
    
    private func analyzeText(_ text: String) -> TextAnalysis {
        let charCount = text.count
        
        // Word count using word boundaries
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        
        // Language detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage?.rawValue
        
        // URL detection
        let detectedUrls = detectURLs(in: text)
        
        return TextAnalysis(
            charCount: charCount,
            wordCount: wordCount,
            language: language,
            detectedUrls: detectedUrls.isEmpty ? nil : detectedUrls
        )
    }
    
    /// Detect URLs in text using NSDataDetector
    private func detectURLs(in text: String) -> [String] {
        var urls: [String] = []
        
        do {
            let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    urls.append(String(text[range]))
                }
            }
        } catch {
            print("URL detection error: \(error)")
        }
        
        return urls
    }
    
    // MARK: - Device Info
    
    private struct DeviceInfo {
        let name: String
        let osVersion: String
    }
    
    private func captureDeviceInfo() -> DeviceInfo {
        let deviceName = Host.current().localizedName ?? "Mac"
        
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        
        return DeviceInfo(name: deviceName, osVersion: osVersion)
    }
    
    // MARK: - Auto Tag Generation
    
    private func generateAutoTags(
        appName: String?,
        bundleId: String?,
        windowTitle: String?,
        hasUrls: Bool,
        method: CaptureMetadata.CaptureMethod
    ) -> [String] {
        var tags: [String] = []
        
        // App-based tags
        if let bundleId = bundleId {
            switch bundleId {
            case let id where id.contains("Safari") || id.contains("Chrome") || id.contains("Firefox") || id.contains("Edge") || id.contains("Brave") || id.contains("Arc"):
                tags.append("web")
            case let id where id.contains("Slack") || id.contains("Discord") || id.contains("Teams"):
                tags.append("chat")
            case let id where id.contains("Mail") || id.contains("Outlook"):
                tags.append("email")
            case let id where id.contains("Notes") || id.contains("Notion") || id.contains("Obsidian"):
                tags.append("notes")
            case let id where id.contains("Xcode") || id.contains("VSCode") || id.contains("Cursor") || id.contains("IntelliJ") || id.contains("PyCharm"):
                tags.append("code")
            case let id where id.contains("Figma") || id.contains("Sketch") || id.contains("Adobe"):
                tags.append("design")
            case let id where id.contains("Terminal") || id.contains("iTerm"):
                tags.append("terminal")
            default:
                break
            }
        }
        
        // Window title based tags
        if let title = windowTitle?.lowercased() {
            if title.contains("github") {
                tags.append("github")
            }
            if title.contains("stackoverflow") || title.contains("stack overflow") {
                tags.append("stackoverflow")
            }
            if title.contains("documentation") || title.contains("docs") {
                tags.append("docs")
            }
            if title.contains("api") {
                tags.append("api")
            }
        }
        
        // URL-based tag
        if hasUrls {
            tags.append("links")
        }
        
        // Remove duplicates and return
        return Array(Set(tags))
    }
}
