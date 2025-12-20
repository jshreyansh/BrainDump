import Foundation
import AppKit
import SwiftUI
import NaturalLanguage

/// Comprehensive metadata captured with each item
struct CaptureMetadata: Codable, Equatable {
    
    // MARK: - Core
    
    /// When the capture occurred
    let capturedAt: Date
    
    /// Timezone of capture
    let timezone: String
    
    /// How the capture was made
    let captureMethod: CaptureMethod
    
    // MARK: - Source Application
    
    /// Name of the app where content was captured from
    let sourceAppName: String?
    
    /// Bundle identifier of source app
    let sourceAppBundleId: String?
    
    /// Window title at time of capture
    let windowTitle: String?
    
    // MARK: - Browser Context (if applicable)
    
    /// URL if captured from a browser
    let url: String?
    
    /// Domain extracted from URL
    let domain: String?
    
    // MARK: - Content Analysis
    
    /// Character count (for text)
    let charCount: Int?
    
    /// Word count (for text)
    let wordCount: Int?
    
    /// Detected language code
    let language: String?
    
    /// Any URLs found in the text
    let detectedUrls: [String]?
    
    // MARK: - Image Info
    
    /// Image dimensions
    let imageWidth: Int?
    let imageHeight: Int?
    
    // MARK: - Device Context
    
    /// Device/computer name
    let deviceName: String?
    
    /// macOS version
    let osVersion: String?
    
    // MARK: - Auto Tags
    
    /// Automatically generated tags based on context
    var autoTags: [String]
    
    // MARK: - Capture Method Enum
    
    enum CaptureMethod: String, Codable {
        case hotkey = "hotkey"
        case bubbleText = "bubble_text"
        case bubbleScreenshot = "bubble_screenshot"
        case bubbleFullScreenshot = "bubble_full_screenshot"
        case dragDrop = "drag_drop"
        case selection = "selection"
        case clipboard = "clipboard"
        case unknown = "unknown"
        
        var displayName: String {
            switch self {
            case .hotkey: return "Hotkey"
            case .bubbleText: return "Quick Note"
            case .bubbleScreenshot: return "Screenshot"
            case .bubbleFullScreenshot: return "Full Screenshot"
            case .dragDrop: return "Drag & Drop"
            case .selection: return "Selection"
            case .clipboard: return "Clipboard"
            case .unknown: return "Captured"
            }
        }
        
        var icon: String {
            switch self {
            case .hotkey: return "command"
            case .bubbleText: return "text.cursor"
            case .bubbleScreenshot, .bubbleFullScreenshot: return "camera"
            case .dragDrop: return "arrow.down.doc"
            case .selection: return "text.cursor"
            case .clipboard: return "doc.on.clipboard"
            case .unknown: return "square.and.arrow.down"
            }
        }
    }
}

// MARK: - YAML Serialization

extension CaptureMetadata {
    
    /// Serialize to YAML-style frontmatter
    func toYAMLFrontmatter() -> String {
        var lines: [String] = ["---"]
        
        // Core
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        lines.append("captured_at: \"\(dateFormatter.string(from: capturedAt))\"")
        lines.append("timezone: \"\(timezone)\"")
        lines.append("capture_method: \"\(captureMethod.rawValue)\"")
        
        // Source App
        if let name = sourceAppName {
            lines.append("source_app: \"\(escapeYAML(name))\"")
        }
        if let bundleId = sourceAppBundleId {
            lines.append("source_bundle_id: \"\(bundleId)\"")
        }
        if let title = windowTitle {
            lines.append("window_title: \"\(escapeYAML(title))\"")
        }
        
        // Browser
        if let url = url {
            lines.append("url: \"\(escapeYAML(url))\"")
        }
        if let domain = domain {
            lines.append("domain: \"\(domain)\"")
        }
        
        // Content Analysis
        if let chars = charCount {
            lines.append("char_count: \(chars)")
        }
        if let words = wordCount {
            lines.append("word_count: \(words)")
        }
        if let lang = language {
            lines.append("language: \"\(lang)\"")
        }
        if let urls = detectedUrls, !urls.isEmpty {
            lines.append("detected_urls:")
            for url in urls.prefix(5) {
                lines.append("  - \"\(escapeYAML(url))\"")
            }
        }
        
        // Image
        if let width = imageWidth, let height = imageHeight {
            lines.append("image_width: \(width)")
            lines.append("image_height: \(height)")
        }
        
        // Device
        if let device = deviceName {
            lines.append("device: \"\(escapeYAML(device))\"")
        }
        if let os = osVersion {
            lines.append("os_version: \"\(os)\"")
        }
        
        // Tags
        if !autoTags.isEmpty {
            lines.append("tags:")
            for tag in autoTags {
                lines.append("  - \"\(tag)\"")
            }
        }
        
        lines.append("---")
        return lines.joined(separator: "\n")
    }
    
    /// Parse from YAML frontmatter string
    static func fromYAMLFrontmatter(_ content: String) -> CaptureMetadata? {
        guard content.hasPrefix("---") else { return nil }
        
        // Find end of frontmatter
        let startIndex = content.index(content.startIndex, offsetBy: 4)
        guard let endRange = content.range(of: "\n---", range: startIndex..<content.endIndex) else {
            return nil
        }
        
        let yamlContent = String(content[startIndex..<endRange.lowerBound])
        
        // Parse YAML lines
        var data: [String: String] = [:]
        var currentArrayKey: String?
        var currentArray: [String] = []
        
        for line in yamlContent.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("- ") {
                // Array item
                let value = String(trimmed.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                currentArray.append(value)
            } else if trimmed.contains(":") {
                // Save previous array
                if let key = currentArrayKey, !currentArray.isEmpty {
                    data[key] = currentArray.joined(separator: "|||")
                    currentArray = []
                }
                
                let parts = trimmed.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let value = String(parts[1]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    
                    if value.isEmpty {
                        currentArrayKey = key
                    } else {
                        data[key] = value
                        currentArrayKey = nil
                    }
                }
            }
        }
        
        // Save last array
        if let key = currentArrayKey, !currentArray.isEmpty {
            data[key] = currentArray.joined(separator: "|||")
        }
        
        // Parse date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let capturedAt: Date
        if let dateStr = data["captured_at"], let date = dateFormatter.date(from: dateStr) {
            capturedAt = date
        } else {
            capturedAt = Date()
        }
        
        let method = CaptureMethod(rawValue: data["capture_method"] ?? "") ?? .unknown
        
        // Parse arrays
        let detectedUrls = data["detected_urls"]?.components(separatedBy: "|||")
        let tags = data["tags"]?.components(separatedBy: "|||") ?? []
        
        return CaptureMetadata(
            capturedAt: capturedAt,
            timezone: data["timezone"] ?? TimeZone.current.identifier,
            captureMethod: method,
            sourceAppName: data["source_app"],
            sourceAppBundleId: data["source_bundle_id"],
            windowTitle: data["window_title"],
            url: data["url"],
            domain: data["domain"],
            charCount: Int(data["char_count"] ?? ""),
            wordCount: Int(data["word_count"] ?? ""),
            language: data["language"],
            detectedUrls: detectedUrls,
            imageWidth: Int(data["image_width"] ?? ""),
            imageHeight: Int(data["image_height"] ?? ""),
            deviceName: data["device"],
            osVersion: data["os_version"],
            autoTags: tags
        )
    }
    
    private func escapeYAML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - Tag Generation

extension CaptureMetadata {
    
    /// Generate display tags for UI
    func generateDisplayTags() -> [DisplayTag] {
        var tags: [DisplayTag] = []
        
        // Source app tag
        if let app = sourceAppName {
            tags.append(DisplayTag(
                text: app,
                icon: "app.badge",
                color: .blue,
                type: .app
            ))
        }
        
        // Capture method tag
        tags.append(DisplayTag(
            text: captureMethod.displayName,
            icon: captureMethod.icon,
            color: .purple,
            type: .method
        ))
        
        // Domain tag (for URLs)
        if let domain = domain {
            tags.append(DisplayTag(
                text: domain,
                icon: "link",
                color: .orange,
                type: .domain
            ))
        }
        
        // Auto-generated tags
        for autoTag in autoTags {
            tags.append(DisplayTag(
                text: autoTag,
                icon: "tag",
                color: .gray,
                type: .auto
            ))
        }
        
        return tags
    }
}

// MARK: - Display Tag Model

struct DisplayTag: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let icon: String
    let color: TagColor
    let type: TagType
    
    enum TagType {
        case app
        case method
        case language
        case domain
        case imageSize
        case wordCount
        case auto
    }
    
    enum TagColor {
        case blue, purple, green, orange, cyan, gray, secondary
        
        var swiftUIColor: some View {
            switch self {
            case .blue: return AnyView(Color.blue)
            case .purple: return AnyView(Color.purple)
            case .green: return AnyView(Color.green)
            case .orange: return AnyView(Color.orange)
            case .cyan: return AnyView(Color.cyan)
            case .gray: return AnyView(Color.gray)
            case .secondary: return AnyView(Color.secondary)
            }
        }
    }
}
