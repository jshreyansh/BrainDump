import SwiftUI

/// List of entries for a selected date
struct EntryListView: View {
    
    let folder: DateFolder?
    @Binding var selectedItem: CapturedItem?
    
    @State private var items: [CapturedItem] = []
    @State private var isLoading = true
    @ObservedObject private var storageManager = StorageManager.shared
    
    var body: some View {
        Group {
            if folder != nil {
                if isLoading {
                    loadingView
                } else if items.isEmpty {
                    emptyView
                } else {
                    listView
                }
            } else {
                noSelectionView
            }
        }
        .onChange(of: folder) { newFolder in
            loadItems(for: newFolder)
        }
        .onChange(of: storageManager.dateFolders) { _ in
            // Refresh items when storage changes
            loadItems(for: folder)
        }
        .onAppear {
            loadItems(for: folder)
        }
    }
    
    // MARK: - Views
    
    private var listView: some View {
        List(selection: $selectedItem) {
            ForEach(items) { item in
                EntryRowView(item: item, isSelected: selectedItem?.id == item.id)
                    .tag(item)
                    .onTapGesture {
                        selectedItem = item
                    }
            }
        }
        .listStyle(.inset)
        .frame(minWidth: 280, idealWidth: 320)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No captures")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Captures for this day will appear here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var noSelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select a date")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Data Loading
    
    private func loadItems(for folder: DateFolder?) {
        guard let folder = folder else {
            items = []
            isLoading = false
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedItems = StorageManager.shared.loadItems(for: folder)
            
            DispatchQueue.main.async {
                // Sort by timestamp descending (newest first)
                self.items = loadedItems.sorted { $0.timestamp > $1.timestamp }
                self.isLoading = false
                
                // Auto-select first item if none selected or current selection not in list
                if selectedItem == nil || !loadedItems.contains(where: { $0.id == selectedItem?.id }) {
                    if !loadedItems.isEmpty {
                        selectedItem = loadedItems.sorted { $0.timestamp > $1.timestamp }.first
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct EntryListView_Previews: PreviewProvider {
    static var previews: some View {
        EntryListView(folder: nil, selectedItem: .constant(nil))
            .frame(width: 320, height: 400)
    }
}
