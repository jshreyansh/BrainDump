import SwiftUI

/// Sidebar showing list of date folders and tags
struct DateListSidebar: View {
    
    @ObservedObject var storageManager = StorageManager.shared
    @Binding var selectedFolder: DateFolder?
    @Binding var selectedTag: String?
    @State private var searchText = ""
    @State private var allTags: [(tag: String, count: Int)] = []
    @State private var isLoadingTags = false
    
    init(selectedFolder: Binding<DateFolder?>, selectedTag: Binding<String?>) {
        self._selectedFolder = selectedFolder
        self._selectedTag = selectedTag
    }
    
    var body: some View {
        List {
            // Captures (Date Folders) Section
            Section {
                ForEach(filteredFolders) { folder in
                    DateFolderRow(folder: folder, isSelected: selectedFolder?.id == folder.id && selectedTag == nil)
                        .tag(folder as DateFolder?)
                        .onTapGesture {
                            selectedTag = nil
                            selectedFolder = folder
                        }
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
            
            // Tags Section
            if !allTags.isEmpty {
                Section {
                    ForEach(filteredTags, id: \.tag) { tagInfo in
                        TagRow(tag: tagInfo.tag, count: tagInfo.count, isSelected: selectedTag == tagInfo.tag)
                            .onTapGesture {
                                if selectedTag == tagInfo.tag {
                                    // Deselect if already selected
                                    selectedTag = nil
                                    // Auto-select today's folder
                                    selectedFolder = storageManager.dateFolders.first
                                } else {
                                    selectedTag = tagInfo.tag
                                    selectedFolder = nil
                                }
                            }
                    }
                } header: {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.secondary)
                        Text("Tags")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search dates or tags")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: refreshAll) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .onAppear {
            refreshAll()
            // Auto-select today if available and nothing selected
            if selectedFolder == nil && selectedTag == nil {
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
    
    // MARK: - Filtered Tags
    
    private var filteredTags: [(tag: String, count: Int)] {
        if searchText.isEmpty {
            return allTags
        }
        return allTags.filter { tagInfo in
            tagInfo.tag.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    private func refreshAll() {
        storageManager.loadDateFolders()
        loadTags()
    }
    
    private func loadTags() {
        isLoadingTags = true
        DispatchQueue.global(qos: .userInitiated).async {
            let tags = StorageManager.shared.getAllTags()
            DispatchQueue.main.async {
                self.allTags = tags
                self.isLoadingTags = false
            }
        }
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: String
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "tag.fill")
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .white : .secondary)
            
            Text(tag)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
            
            // Item count badge
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.5))
                )
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

// MARK: - Date Folder Row

struct DateFolderRow: View {
    
    let folder: DateFolder
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.relativeDisplayName)
                    .font(.system(size: 13, weight: (folder.isToday || isSelected) ? .semibold : .regular))
                    .foregroundColor((folder.isToday || isSelected) ? (isSelected ? .white : .accentColor) : .primary)
                
                if !folder.isToday && !folder.isYesterday {
                    Text(folder.folderName)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
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
                        .fill(isSelected ? Color.white.opacity(0.3) : (folder.isToday ? Color.accentColor : Color.gray.opacity(0.5)))
                )
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

// MARK: - Preview

struct DateListSidebar_Previews: PreviewProvider {
    static var previews: some View {
        DateListSidebar(selectedFolder: .constant(nil), selectedTag: .constant(nil))
            .frame(width: 250)
    }
}



