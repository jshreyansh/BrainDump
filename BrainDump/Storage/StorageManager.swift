import Foundation
import AppKit
import Combine

/// Singleton manager for all file storage operations
final class StorageManager: ObservableObject {
    
    static let shared = StorageManager()
    
    /// Published list of date folders for UI binding
    @Published private(set) var dateFolders: [DateFolder] = []
    
    /// The root storage directory
    private(set) var storageURL: URL
    
    /// Settings key for custom storage location
    private static let storageLocationKey = "settings.storage.location"
    
    private let fileManager = FileManager.default
    
    private init() {
        // Default storage location
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.storageURL = appSupport.appendingPathComponent("BrainDumpAI", isDirectory: true)
        
        // Check for custom storage location
        if let customPath = UserDefaults.standard.string(forKey: Self.storageLocationKey) {
            let customURL = URL(fileURLWithPath: customPath)
            if fileManager.fileExists(atPath: customURL.path) {
                self.storageURL = customURL
            }
        }
        
        // Ensure storage directory exists
        createStorageDirectoryIfNeeded()
        
        // Load initial data
        loadDateFolders()
    }
    
    // MARK: - Storage Directory Management
    
    private func createStorageDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: storageURL.path) {
            try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
        }
    }
    
    /// Get or create today's folder
    private func getTodayFolder() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayName = formatter.string(from: Date())
        let todayURL = storageURL.appendingPathComponent(todayName, isDirectory: true)
        
        if !fileManager.fileExists(atPath: todayURL.path) {
            try? fileManager.createDirectory(at: todayURL, withIntermediateDirectories: true)
        }
        
        return todayURL
    }
    
    /// Generate a unique filename with timestamp (includes milliseconds for uniqueness)
    private func generateFilename(extension ext: String) -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH-mm-ss"
        let baseName = formatter.string(from: now)
        
        // Add milliseconds for better uniqueness
        let milliseconds = Int(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1000)
        
        let todayFolder = getTodayFolder()
        var filename = "\(baseName)-\(String(format: "%03d", milliseconds)).\(ext)"
        var counter = 1
        
        // Handle same-millisecond captures by appending a counter
        while fileManager.fileExists(atPath: todayFolder.appendingPathComponent(filename).path) {
            filename = "\(baseName)-\(String(format: "%03d", milliseconds))-\(counter).\(ext)"
            counter += 1
        }
        
        return filename
    }
    
    // MARK: - Save Methods
    
    /// Save text content and return the created item
    /// - Parameters:
    ///   - text: The text content to save
    ///   - method: The capture method used
    ///   - sourceApp: Optional source app to use for metadata (useful when BrainDump is frontmost)
    @discardableResult
    func saveText(_ text: String, method: CaptureMetadata.CaptureMethod = .unknown, sourceApp: NSRunningApplication? = nil) -> CapturedItem? {
        let todayFolder = getTodayFolder()
        let filename = generateFilename(extension: "md")
        let fileURL = todayFolder.appendingPathComponent(filename)
        
        // Capture metadata
        let metadata = MetadataCapture.shared.captureForText(text, method: method, sourceApp: sourceApp)
        
        // Format content with metadata frontmatter
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = metadata.toYAMLFrontmatter() + "\n\n" + trimmedText + "\n"
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            loadDateFolders() // Refresh the folder list
            return CapturedItem.from(fileURL: fileURL)
        } catch {
            print("Error saving text: \(error)")
            return nil
        }
    }
    
    /// Save image and return the created item
    @discardableResult
    func saveImage(_ image: NSImage, method: CaptureMetadata.CaptureMethod = .unknown) -> CapturedItem? {
        let todayFolder = getTodayFolder()
        let baseFilename = generateFilename(extension: "png")
        let imageURL = todayFolder.appendingPathComponent(baseFilename)
        
        // Also save metadata in a sidecar file
        let metadataFilename = baseFilename.replacingOccurrences(of: ".png", with: ".meta.yaml")
        let metadataURL = todayFolder.appendingPathComponent(metadataFilename)
        
        // Capture metadata
        let metadata = MetadataCapture.shared.captureForImage(image, method: method)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Error converting image to PNG")
            return nil
        }
        
        do {
            try pngData.write(to: imageURL)
            
            // Save metadata sidecar file
            let metadataContent = metadata.toYAMLFrontmatter()
            try metadataContent.write(to: metadataURL, atomically: true, encoding: .utf8)
            
            loadDateFolders() // Refresh the folder list
            return CapturedItem.from(fileURL: imageURL)
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    /// Save data from a file URL (for drag & drop)
    @discardableResult
    func saveFromFileURL(_ sourceURL: URL) -> CapturedItem? {
        let fileExtension = sourceURL.pathExtension.lowercased()
        
        // Determine if it's an image or text
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp"]
        let textExtensions = ["txt", "md", "rtf"]
        
        if imageExtensions.contains(fileExtension) {
            // Copy image file
            if let image = NSImage(contentsOf: sourceURL) {
                return saveImage(image, method: .dragDrop)
            }
        } else if textExtensions.contains(fileExtension) {
            // Copy text file
            if let text = try? String(contentsOf: sourceURL, encoding: .utf8) {
                return saveText(text, method: .dragDrop)
            }
        } else {
            // Try to read as text
            if let text = try? String(contentsOf: sourceURL, encoding: .utf8) {
                return saveText(text, method: .dragDrop)
            }
        }
        
        return nil
    }
    
    // MARK: - Load Methods
    
    /// Load all date folders sorted by date descending
    func loadDateFolders() {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: storageURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            let folders = contents
                .filter { url in
                    var isDirectory: ObjCBool = false
                    return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                }
                .compactMap { DateFolder.from(folderURL: $0) }
                .sorted { $0.date > $1.date }
            
            DispatchQueue.main.async {
                self.dateFolders = folders
            }
        } catch {
            print("Error loading date folders: \(error)")
            DispatchQueue.main.async {
                self.dateFolders = []
            }
        }
    }
    
    /// Load all items for a specific date folder
    func loadItems(for dateFolder: DateFolder) -> [CapturedItem] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: dateFolder.folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // Create items and sort by file modification date (most reliable)
            var itemsWithDates: [(item: CapturedItem, modDate: Date)] = []
            
            for url in contents {
                if let item = CapturedItem.from(fileURL: url) {
                    let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? item.timestamp
                    itemsWithDates.append((item, modDate))
                }
            }
            
            // Sort by modification date descending (newest first)
            return itemsWithDates
                .sorted { $0.modDate > $1.modDate }
                .map { $0.item }
        } catch {
            print("Error loading items: \(error)")
            return []
        }
    }
    
    /// Load items for a specific date
    func loadItems(for date: Date) -> [CapturedItem] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let folderName = formatter.string(from: date)
        let folderURL = storageURL.appendingPathComponent(folderName, isDirectory: true)
        
        guard let dateFolder = DateFolder.from(folderURL: folderURL) else {
            return []
        }
        
        return loadItems(for: dateFolder)
    }
    
    // MARK: - Edit Methods
    
    /// Edit text content of a text item (preserves metadata frontmatter)
    func editText(_ item: CapturedItem, newText: String) -> Bool {
        guard item.type == .text else { return false }
        
        // Load existing file to preserve frontmatter
        guard let existingContent = try? String(contentsOf: item.filePath, encoding: .utf8) else {
            return false
        }
        
        // Extract frontmatter if present
        var frontmatter = ""
        var contentStart = existingContent.startIndex
        
        if existingContent.hasPrefix("---\n") {
            let startIndex = existingContent.index(existingContent.startIndex, offsetBy: 4)
            if let endRange = existingContent.range(of: "\n---\n", range: startIndex..<existingContent.endIndex) {
                frontmatter = String(existingContent[..<endRange.upperBound])
                contentStart = endRange.upperBound
            }
        }
        
        // Format new content with preserved frontmatter
        let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newContent: String
        if frontmatter.isEmpty {
            // No frontmatter, just save the text
            newContent = trimmedText + "\n"
        } else {
            // Preserve frontmatter and update content
            newContent = frontmatter + "\n\n" + trimmedText + "\n"
        }
        
        do {
            try newContent.write(to: item.filePath, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Error editing text: \(error)")
            return false
        }
    }
    
    // MARK: - Delete Methods
    
    /// Delete a captured item
    func deleteItem(_ item: CapturedItem) -> Bool {
        do {
            // Also delete metadata file if it's an image
            if item.type == .image {
                let metadataPath = item.filePath.deletingPathExtension().appendingPathExtension("meta.yaml")
                if fileManager.fileExists(atPath: metadataPath.path) {
                    try? fileManager.removeItem(at: metadataPath)
                }
            }
            
            try fileManager.removeItem(at: item.filePath)
            loadDateFolders() // Refresh
            return true
        } catch {
            print("Error deleting item: \(error)")
            return false
        }
    }
    
    /// Delete an entire date folder
    func deleteDateFolder(_ folder: DateFolder) -> Bool {
        do {
            try fileManager.removeItem(at: folder.folderURL)
            loadDateFolders() // Refresh
            return true
        } catch {
            print("Error deleting folder: \(error)")
            return false
        }
    }
    
    // MARK: - Open in System App
    
    /// Open the item in the default system application
    func openInSystemApp(_ item: CapturedItem) {
        NSWorkspace.shared.open(item.filePath)
    }
    
    /// Reveal the item in Finder
    func revealInFinder(_ item: CapturedItem) {
        NSWorkspace.shared.selectFile(item.filePath.path, inFileViewerRootedAtPath: "")
    }
    
    // MARK: - Storage Location
    
    /// Update the storage location
    func setStorageLocation(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: Self.storageLocationKey)
        storageURL = url
        createStorageDirectoryIfNeeded()
        loadDateFolders()
    }
    
    /// Reset to default storage location
    func resetStorageLocation() {
        UserDefaults.standard.removeObject(forKey: Self.storageLocationKey)
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("BrainDumpAI", isDirectory: true)
        createStorageDirectoryIfNeeded()
        loadDateFolders()
    }
}

