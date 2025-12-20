import Foundation

/// Represents a date-based folder containing captured items
struct DateFolder: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let folderURL: URL
    var itemCount: Int
    
    /// The folder name (format: yyyy-MM-dd)
    var folderName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// Display date for the sidebar (e.g., "December 9, 2025")
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    /// Short display date (e.g., "Dec 9")
    var shortDisplayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    /// Check if this folder is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Check if this folder is for yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    /// Relative display name (Today, Yesterday, or the date)
    var relativeDisplayName: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return displayDate
        }
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DateFolder, rhs: DateFolder) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Factory Methods

extension DateFolder {
    /// Create a DateFolder from a folder URL
    static func from(folderURL: URL) -> DateFolder? {
        let folderName = folderURL.lastPathComponent
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: folderName) else {
            return nil
        }
        
        // Count items in folder (exclude metadata files and other non-item files)
        let fileManager = FileManager.default
        let itemCount = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            .filter { url in
                // Exclude hidden files
                guard !url.lastPathComponent.hasPrefix(".") else { return false }
                // Exclude metadata files (.meta.yaml)
                let fileName = url.lastPathComponent
                guard !fileName.hasSuffix(".meta.yaml") else { return false }
                // Only count files that can be converted to CapturedItem
                return CapturedItem.from(fileURL: url) != nil
            }
            .count) ?? 0
        
        return DateFolder(
            id: UUID(),
            date: date,
            folderURL: folderURL,
            itemCount: itemCount
        )
    }
}



