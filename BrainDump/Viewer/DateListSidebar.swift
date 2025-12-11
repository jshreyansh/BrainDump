import SwiftUI

/// Sidebar showing list of date folders
struct DateListSidebar: View {
    
    @ObservedObject var storageManager = StorageManager.shared
    @Binding var selectedFolder: DateFolder?
    @State private var searchText = ""
    
    var body: some View {
        List(selection: $selectedFolder) {
            Section {
                ForEach(filteredFolders) { folder in
                    DateFolderRow(folder: folder)
                        .tag(folder)
                }
            } header: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text("Captures")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search dates")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: refreshFolders) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .onAppear {
            storageManager.loadDateFolders()
            // Auto-select today if available
            if selectedFolder == nil {
                selectedFolder = storageManager.dateFolders.first
            }
        }
    }
    
    // MARK: - Filtered Folders
    
    private var filteredFolders: [DateFolder] {
        if searchText.isEmpty {
            return storageManager.dateFolders
        }
        return storageManager.dateFolders.filter { folder in
            folder.displayDate.localizedCaseInsensitiveContains(searchText) ||
            folder.folderName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    private func refreshFolders() {
        storageManager.loadDateFolders()
    }
}

// MARK: - Date Folder Row

struct DateFolderRow: View {
    
    let folder: DateFolder
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.relativeDisplayName)
                    .font(.system(size: 13, weight: folder.isToday ? .semibold : .regular))
                    .foregroundColor(folder.isToday ? .accentColor : .primary)
                
                if !folder.isToday && !folder.isYesterday {
                    Text(folder.folderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Item count badge
            Text("\(folder.itemCount)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(folder.isToday ? Color.accentColor : Color.gray.opacity(0.5))
                )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

struct DateListSidebar_Previews: PreviewProvider {
    static var previews: some View {
        DateListSidebar(selectedFolder: .constant(nil))
            .frame(width: 250)
    }
}



