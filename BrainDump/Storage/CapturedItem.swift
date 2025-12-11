import Foundation
import AppKit

/// Represents a single captured item (text or image)
struct CapturedItem: Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let type: ItemType
    let filePath: URL
    
    enum ItemType: String, Codable {
        case text
        case image
    }
    
    /// The filename without extension
    var fileName: String {
        filePath.deletingPathExtension().lastPathComponent
    }
    
    /// Display time (e.g., "14:03:22")
    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    /// Load metadata for this item
    func loadMetadata() -> CaptureMetadata? {
        switch type {
        case .text:
            // Metadata is embedded in the file frontmatter
            guard let fullContent = try? String(contentsOf: filePath, encoding: .utf8) else { return nil }
            return CaptureMetadata.fromYAMLFrontmatter(fullContent)
            
        case .image:
            // Metadata is in a sidecar file
            let metadataPath = filePath.deletingPathExtension().appendingPathExtension("meta.yaml")
            guard let content = try? String(contentsOf: metadataPath, encoding: .utf8) else { return nil }
            return CaptureMetadata.fromYAMLFrontmatter(content)
        }
    }
    
    /// Load display tags for UI
    func loadDisplayTags() -> [DisplayTag] {
        guard let metadata = loadMetadata() else {
            return []
        }
        return metadata.generateDisplayTags()
    }
    
    /// Load the text content from file (strips the header if present)
    func loadTextContent() -> String? {
        guard type == .text else { return nil }
        guard let fullContent = try? String(contentsOf: filePath, encoding: .utf8) else { return nil }
        
        // Remove the YAML-style header if present
        // Header format: ---\n...\n---\n\n
        if fullContent.hasPrefix("---\n") {
            // Find the closing ---
            let startIndex = fullContent.index(fullContent.startIndex, offsetBy: 4)
            if let endRange = fullContent.range(of: "\n---\n", range: startIndex..<fullContent.endIndex) {
                // Return content after the frontmatter
                let contentStart = endRange.upperBound
                let content = String(fullContent[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return content.isEmpty ? nil : content
            }
        }
        
        return fullContent
    }
    
    /// Load the raw file content (includes header)
    func loadRawContent() -> String? {
        guard type == .text else { return nil }
        return try? String(contentsOf: filePath, encoding: .utf8)
    }
    
    /// Load the image from file
    func loadImage() -> NSImage? {
        guard type == .image else { return nil }
        return NSImage(contentsOf: filePath)
    }
    
    /// Get a preview of the content (first line or 80 chars)
    var contentPreview: String {
        switch type {
        case .text:
            if let content = loadTextContent() {
                let firstLine = content.components(separatedBy: .newlines).first ?? content
                let preview = firstLine.prefix(80)
                return preview.count < firstLine.count ? "\(preview)..." : String(preview)
            }
            return "Unable to load content"
        case .image:
            return "🖼️ Image"
        }
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CapturedItem, rhs: CapturedItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory Methods

extension CapturedItem {
    /// Create a CapturedItem from an existing file URL
    static func from(fileURL: URL) -> CapturedItem? {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Determine type from extension
        let type: ItemType
        switch fileExtension {
        case "md", "txt", "rtf":
            type = .text
        case "png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp":
            type = .image
        default:
            return nil
        }
        
        // Get the date from the parent folder name (format: yyyy-MM-dd)
        let parentFolder = fileURL.deletingLastPathComponent().lastPathComponent
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var timestamp: Date
        
        // Try to parse timestamp from filename
        // Filename formats: 
        // - HH-mm-ss.ext (old format)
        // - HH-mm-ss-NNN.ext (new format with milliseconds)
        // - HH-mm-ss-NNN-N.ext (new format with counter)
        
        if let folderDate = dateFormatter.date(from: parentFolder) {
            // Extract time components from filename
            let parts = fileName.components(separatedBy: "-")
            
            if parts.count >= 3,
               let hour = Int(parts[0]),
               let minute = Int(parts[1]),
               let second = Int(parts[2].prefix(2)) { // Take only first 2 chars in case of milliseconds
                
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: folderDate)
                components.hour = hour
                components.minute = minute
                components.second = second
                
                // Try to get milliseconds if present
                if parts.count >= 4, let ms = Int(parts[3].prefix(3)) {
                    // We can't store milliseconds in Date easily, but we'll use file mod date for ordering
                }
                
                if let combinedDate = calendar.date(from: components) {
                    timestamp = combinedDate
                } else {
                    timestamp = getFileModificationDate(fileURL) ?? folderDate
                }
            } else {
                timestamp = getFileModificationDate(fileURL) ?? folderDate
            }
        } else {
            // Fallback: use file modification date
            timestamp = getFileModificationDate(fileURL) ?? Date()
        }
        
        return CapturedItem(
            id: UUID(),
            timestamp: timestamp,
            type: type,
            filePath: fileURL
        )
    }
    
    /// Get file modification date
    private static func getFileModificationDate(_ url: URL) -> Date? {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modDate = attrs[.modificationDate] as? Date {
            return modDate
        }
        return nil
    }
}
