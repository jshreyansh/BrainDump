import SwiftUI

/// Timeline view showing all entries for selected date(s) in a continuous scrollable view
struct EntryDetailView: View {
    
    let folder: DateFolder?
    @State private var items: [CapturedItem] = []
    @State private var isLoading = true
    @ObservedObject private var storageManager = StorageManager.shared
    
    var body: some View {
        Group {
            if let folder = folder {
                if isLoading {
                    loadingView
                } else if items.isEmpty {
                    emptyView
                } else {
                    timelineView(for: folder)
                }
            } else {
                noSelectionView
            }
        }
        .onChange(of: folder) { newFolder in
            loadItems(for: newFolder)
        }
        .onChange(of: storageManager.dateFolders) { _ in
            loadItems(for: folder)
        }
        .onAppear {
            loadItems(for: folder)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ItemDeleted"))) { _ in
            // Refresh when an item is deleted
            loadItems(for: folder)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ItemEdited"))) { _ in
            // Refresh when an item is edited
            loadItems(for: folder)
        }
    }
    
    // MARK: - Timeline View
    
    private func timelineView(for folder: DateFolder) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Date Header
                dateHeader(for: folder)
                
                // All entries in chronological order
                ForEach(items) { item in
                    EntryCard(item: item)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    
                    // Divider between entries
                    if item.id != items.last?.id {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
                
                // Bottom padding
                Spacer()
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func dateHeader(for folder: DateFolder) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(folder.relativeDisplayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(items.count) captures")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.15)))
            }
            
            Text(folder.folderName)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading States
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading captures...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No captures for this day")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Drag text or images to the floating bubble,\nor use ⌘⌥D to capture selected text")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select a date")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Choose a date from the sidebar to view captures")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
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
            // Sort by timestamp DESCENDING (newest at top)
            let sortedItems = loadedItems.sorted { $0.timestamp > $1.timestamp }
            
            DispatchQueue.main.async {
                self.items = sortedItems
                self.isLoading = false
            }
        }
    }
}

// MARK: - Entry Card (Individual entry in timeline)

struct EntryCard: View {
    let item: CapturedItem
    @State private var textContent: String = ""
    @State private var isLoaded = false
    @State private var displayTags: [DisplayTag] = []
    @State private var isExpanded = false
    @State private var needsExpansion = false
    @State private var isEditing = false
    @State private var editedText: String = ""
    @State private var showDeleteConfirmation = false
    @ObservedObject private var storageManager = StorageManager.shared

    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Timestamp header
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: item.type == .text ? "doc.text" : "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(item.type == .text ? Color.blue : Color.purple)
                    )
                
                Text(item.displayTime)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    // Edit button (only for text items)
                    if item.type == .text {
                        Button(action: {
                            editedText = textContent
                            isEditing = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24)
                        .help("Edit")
                    }
                    
                    // Delete button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 24)
                    .help("Delete")
                    
                    // Copy button (only for text items)
                    if item.type == .text {
                        Button(action: {
                            if let text = item.loadTextContent() {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                            }
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 24)
                        .help("Copy")
                    }
                    
                    // Menu button (hamburger icon - using Menu with hidden indicator)
                    Menu {
                        Button("Open in Default App") {
                            StorageManager.shared.openInSystemApp(item)
                        }
                        Button("Reveal in Finder") {
                            StorageManager.shared.revealInFinder(item)
                        }
                        Divider()
                        Button("Copy File Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.filePath.path, forType: .string)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 24)
                }
            }
            
            // Metadata Tags
            if !displayTags.isEmpty {
                MetadataTagsView(tags: displayTags)
            }
            
            // Content
            contentView
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .onAppear {
            loadContent()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ItemEdited"))) { notification in
            // Reload content if this item was edited
            if let editedItemId = notification.object as? UUID, editedItemId == item.id {
                isLoaded = false
                loadContent()
            }
        }
        .sheet(isPresented: $isEditing) {
            EditTextView(item: item, text: $editedText, isPresented: $isEditing)
        }
        .alert("Delete Item", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }
    
    private func deleteItem() {
        if storageManager.deleteItem(item) {
            // Trigger refresh by posting notification
            NotificationCenter.default.post(name: NSNotification.Name("ItemDeleted"), object: item.id)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch item.type {
        case .text:
            if isLoaded {
                VStack(alignment: .leading, spacing: 8) {
                    // Text content with expandable functionality
                    if isExpanded {
                        // Full text when expanded
                        Text(textContent)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        // Truncated text when collapsed (4 lines)
                        // Use explicit frame constraints and clipping to force truncation
                        Text(textContent)
                            .font(.body)
                            .textSelection(.enabled)
                            .lineSpacing(4)
                            .lineLimit(4)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, maxHeight: 100, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: false)
                            .clipped()
                    }
                    
                    // Show more/less button - show if text needs expansion
                    if needsExpansion {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(isExpanded ? "Show less" : "Show more")
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                ProgressView()
                    .frame(height: 40)
            }
            
        case .image:
            if let image = item.loadImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Unable to load image")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func loadContent() {
        guard !isLoaded else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let content = item.type == .text ? (item.loadTextContent() ?? "") : ""
            let tags = item.loadDisplayTags()
            
            DispatchQueue.main.async {
                self.textContent = content
                self.displayTags = tags
                self.isLoaded = true
                // Check if expansion is needed after content loads
                self.checkIfExpansionNeeded()
            }
        }
    }
    
    private func checkIfExpansionNeeded() {
        // Aggressive check: Always show expand for text that's likely to exceed 4-5 lines
        // Check multiple criteria to catch different cases
        
        guard !textContent.isEmpty else {
            needsExpansion = false
            return
        }
        
        // 1. Character count - if text is longer than ~250 chars, it's likely more than 4-5 lines
        let charCount = textContent.count
        
        // 2. Newline count - if there are more than 3 explicit newlines
        let newlineCount = textContent.components(separatedBy: .newlines).count
        
        // 3. Word count - if there are more than ~40 words, likely exceeds 4-5 lines
        let wordCount = textContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        
        // Show expansion if ANY of these conditions are met
        // Lowered thresholds to be more aggressive and catch more cases
        needsExpansion = charCount > 250 || newlineCount > 3 || wordCount > 40
        
        // Debug: Force expansion for very long text as safety net
        if charCount > 1000 || wordCount > 100 {
            needsExpansion = true
        }
    }
}

// MARK: - Metadata Tags View

struct MetadataTagsView: View {
    let tags: [DisplayTag]
    
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags) { tag in
                TagPill(tag: tag)
            }
        }
    }
}

// MARK: - Individual Tag Pill

struct TagPill: View {
    let tag: DisplayTag
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.system(size: 9))
            
            Text(tag.text)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(foregroundColor)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
    }
    
    private var foregroundColor: Color {
        switch tag.color {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .cyan: return .cyan
        case .gray: return .gray
        case .secondary: return .secondary
        }
    }
    
    private var backgroundColor: Color {
        switch tag.color {
        case .blue: return .blue.opacity(0.15)
        case .purple: return .purple.opacity(0.15)
        case .green: return .green.opacity(0.15)
        case .orange: return .orange.opacity(0.15)
        case .cyan: return .cyan.opacity(0.15)
        case .gray: return .gray.opacity(0.15)
        case .secondary: return .secondary.opacity(0.1)
        }
    }
}

// MARK: - Flow Layout for wrapping tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }
        
        totalHeight = currentY + lineHeight
        
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

// MARK: - Empty State (for backward compatibility)

struct EntryDetailEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Select a date to view captures")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Your captured text and images will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Edit Text View

struct EditTextView: View {
    let item: CapturedItem
    @Binding var text: String
    @Binding var isPresented: Bool
    @State private var editedText: String = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Edit Note")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }
            
            // Text editor
            TextEditor(text: $editedText)
                .font(.body)
                .frame(minHeight: 300)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isFocused)
            
            // Footer with save button
            HStack {
                Spacer()
                
                Button("Save") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 600, height: 450)
        .onAppear {
            editedText = text
            // Focus the text editor after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
    
    private func saveChanges() {
        if StorageManager.shared.editText(item, newText: editedText) {
            text = editedText
            // Post notification to refresh the list
            NotificationCenter.default.post(name: NSNotification.Name("ItemEdited"), object: item.id)
            isPresented = false
        }
    }
}

// MARK: - Preview

struct EntryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        EntryDetailEmptyView()
            .frame(width: 500, height: 400)
    }
}
