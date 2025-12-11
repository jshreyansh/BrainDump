import SwiftUI

/// Main view with two-column layout: date sidebar + timeline view
struct MainView: View {
    
    @StateObject private var storageManager = StorageManager.shared
    @State private var selectedFolder: DateFolder?
    
    var body: some View {
        NavigationSplitView {
            // Left: Date folders sidebar
            DateListSidebar(selectedFolder: $selectedFolder)
        } detail: {
            // Right: Timeline view showing all captures for selected date
            EntryDetailView(folder: selectedFolder)
        }
        .navigationTitle("BrainDump")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: refreshAll) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .keyboardShortcut("r", modifiers: .command)
                
                Button(action: toggleBubble) {
                    Image(systemName: FloatingBubbleController.shared.isVisible ? "bubble.fill" : "bubble")
                }
                .help(FloatingBubbleController.shared.isVisible ? "Hide Floating Bubble" : "Show Floating Bubble")
                
                Button(action: captureFromClipboard) {
                    Image(systemName: "plus.circle")
                }
                .help("Capture from Clipboard (⇧⌘V)")
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
        .onChange(of: storageManager.dateFolders) { folders in
            // Auto-select today's folder when folders change
            if selectedFolder == nil || !folders.contains(where: { $0.id == selectedFolder?.id }) {
                selectedFolder = folders.first
            }
        }
        .onAppear {
            // Initial selection - select today
            if selectedFolder == nil {
                selectedFolder = storageManager.dateFolders.first
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleBubble() {
        FloatingBubbleController.shared.toggle()
    }
    
    private func captureFromClipboard() {
        let clipboard = ClipboardHelper.shared
        
        // Try text first
        if let text = clipboard.readText(), !text.isEmpty {
            if StorageManager.shared.saveText(text) != nil {
                refreshAndSelectToday()
                ToastManager.shared.show()
            }
            return
        }
        
        // Try image
        if let image = clipboard.readImage() {
            if StorageManager.shared.saveImage(image) != nil {
                refreshAndSelectToday()
                ToastManager.shared.show()
            }
        }
    }
    
    private func refreshAll() {
        StorageManager.shared.loadDateFolders()
    }
    
    private func refreshAndSelectToday() {
        StorageManager.shared.loadDateFolders()
        // Ensure today's folder is selected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let todayFolder = storageManager.dateFolders.first(where: { $0.isToday }) {
                selectedFolder = todayFolder
            } else if let firstFolder = storageManager.dateFolders.first {
                selectedFolder = firstFolder
            }
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
