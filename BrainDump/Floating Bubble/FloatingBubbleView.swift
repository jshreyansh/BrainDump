import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ApplicationServices

/// The visual appearance of the floating capture bubble with expandable actions
struct FloatingBubbleView: View {
    
    @State private var isHovering = false
    @State private var isPulsing = false
    @State private var isDragOver = false
    @State private var isExpanded = false
    @State private var showTextInput = false
    @State private var textInputValue = ""
    
    /// Callback when content is dropped/saved
    var onDrop: ((Any) -> Void)?
    
    /// Callback to show toast
    var onShowToast: (() -> Void)?
    
    /// Callback to start screenshot capture
    var onScreenshotCapture: (() -> Void)?
    
    private let bubbleSize: CGFloat = 48
    private let actionButtonSize: CGFloat = 36
    private let expandedRadius: CGFloat = 50
    
    // Pill shape dimensions for default state
    private let pillWidth: CGFloat = 120
    private let pillHeight: CGFloat = 32
    private let pillCornerRadius: CGFloat = 16
    
    var body: some View {
        ZStack {
            // Action buttons (shown when expanded)
            if isExpanded {
                // Text button - positioned to the left
                ActionButton(
                    icon: "text.cursor",
                    label: "Text",
                    color: .blue
                ) {
                    // Capture the previous active app BEFORE BrainDump becomes active
                    // This ensures we get the correct source app for metadata
                    FloatingBubbleController.shared.capturePreviousActiveApp()
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showTextInput = true
                        isExpanded = false
                    }
                }
                .offset(x: -expandedRadius, y: -30)
                .transition(.scale.combined(with: .opacity))
                
                // Image/Screenshot button (interactive selection) - positioned to the right
                ActionButton(
                    icon: "camera.viewfinder",
                    label: "Select",
                    color: .purple
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                    // Slight delay to allow animation, then capture
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        startScreenshotCapture()
                    }
                }
                .offset(x: expandedRadius, y: -30)
                .transition(.scale.combined(with: .opacity))
                
                // Full screenshot button - positioned below
                ActionButton(
                    icon: "camera.fill",
                    label: "Full",
                    color: .orange
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = false
                    }
                    // Slight delay to allow animation, then capture
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        startFullScreenshotCapture()
                    }
                }
                .offset(x: 0, y: expandedRadius + 10)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Text input popup (shown when text mode is active)
            if showTextInput {
                TextInputPopup(
                    text: $textInputValue,
                    onSubmit: { text in
                        saveTextInput(text)
                    },
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showTextInput = false
                            textInputValue = ""
                        }
                    }
                )
                .offset(y: -100)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity)
                ))
            }
            
            // Main bubble - pill shape when collapsed, circle when expanded
            ZStack {
                if isExpanded {
                    // Expanded state: Circle (keeping original design)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: bubbleSize, height: bubbleSize)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    
                    // Inner glow when expanded
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.accentColor.opacity(isDragOver ? 0.3 : 0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: bubbleSize / 2
                            )
                        )
                        .frame(width: bubbleSize, height: bubbleSize)
                    
                    // Expanded state ring
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.5), Color.blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: bubbleSize + 6, height: bubbleSize + 6)
                } else {
                    // Default state: Pill shape with Apple's glass material
                    RoundedRectangle(cornerRadius: pillCornerRadius)
                        .fill(.ultraThinMaterial)
                        .frame(width: pillWidth, height: pillHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: pillCornerRadius)
                                .strokeBorder(
                                    Color.primary.opacity(isHovering ? 0.3 : 0.15),
                                    lineWidth: isHovering ? 1.5 : 1.0
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // Subtle inner glow on hover/drag
                    if isHovering || isDragOver {
                        RoundedRectangle(cornerRadius: pillCornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(isDragOver ? 0.15 : 0.08),
                                        Color.clear
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: pillWidth, height: pillHeight)
                    }
                }
                
                // Brain icon (changes when expanded)
                Image(systemName: isExpanded ? "xmark" : "brain.head.profile")
                    .font(.system(size: isExpanded ? 18 : 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isExpanded ? [Color.gray, Color.gray.opacity(0.7)] : [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isPulsing ? 1.15 : 1.0)
                
                // Drop indicator (works for both pill and circle)
                if isDragOver {
                    if isExpanded {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: bubbleSize + 8, height: bubbleSize + 8)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: pillCornerRadius + 2)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: pillWidth + 4, height: pillHeight + 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPulsing)
            .animation(.easeInOut(duration: 0.2), value: isDragOver)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isExpanded)
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                handleClick()
            }
            .onDrop(of: supportedTypes, isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
        .onChange(of: isExpanded) { newValue in
            // Notify controller to resize panel
            FloatingBubbleController.shared.updatePanelSize(isExpanded: newValue, showTextInput: showTextInput)
        }
        .onChange(of: showTextInput) { newValue in
            // Notify controller to resize panel
            FloatingBubbleController.shared.updatePanelSize(isExpanded: isExpanded, showTextInput: newValue)
        }
        .onAppear {
            // Set initial size when view appears
            FloatingBubbleController.shared.updatePanelSize(isExpanded: isExpanded, showTextInput: showTextInput)
        }
    }
    
    // MARK: - Supported Drop Types
    
    private var supportedTypes: [UTType] {
        [
            .png, .jpeg, .tiff, .bmp, .gif, .image,
            .fileURL, .url, .text, .plainText, .utf8PlainText
        ]
    }
    
    // MARK: - Click Handler
    
    private func handleClick() {
        // If text input is showing, don't toggle expand
        if showTextInput {
            return
        }
        
        // Toggle expanded state
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            isExpanded.toggle()
        }
        
        triggerPulse()
    }
    
    // MARK: - Text Input Save
    
    private func saveTextInput(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showTextInput = false
                textInputValue = ""
            }
            return
        }
        
        print("BrainDump: Saving manual text input (\(trimmedText.count) chars)")
        
        // Get the previous active app (captured before BrainDump became frontmost)
        // This allows us to capture the source app metadata correctly
        let sourceApp = FloatingBubbleController.shared.previousActiveApp
        
        if let appName = sourceApp?.localizedName {
            print("BrainDump: Using source app: \(appName) (bundle: \(sourceApp?.bundleIdentifier ?? "unknown"))")
        } else {
            print("BrainDump: ⚠️ No source app captured - will use current frontmost app")
        }
        
        if let savedItem = StorageManager.shared.saveText(trimmedText, method: .bubbleText, sourceApp: sourceApp) {
            print("BrainDump: ✅ Text input saved")
            onDrop?(savedItem)
            onShowToast?()
        } else {
            print("BrainDump: ❌ Failed to save text input")
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showTextInput = false
            textInputValue = ""
        }
    }
    
    // MARK: - Screenshot Capture
    
    private func startScreenshotCapture() {
        print("BrainDump: Starting interactive screenshot capture")
        
        // Use macOS screencapture in interactive mode
        // -i = interactive mode (like Cmd+Shift+4)
        // -c = copy to clipboard instead of file
        // -x = no sound
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-c", "-x"]
        
        task.terminationHandler = { [self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    // Check if there's an image in the clipboard
                    if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                        print("BrainDump: Screenshot captured, saving...")
                        
                        if let savedItem = StorageManager.shared.saveImage(image, method: .bubbleScreenshot) {
                            print("BrainDump: ✅ Screenshot saved")
                            onDrop?(savedItem)
                            onShowToast?()
                            triggerPulse()
                        } else {
                            print("BrainDump: ❌ Failed to save screenshot")
                        }
                    } else {
                        print("BrainDump: Screenshot cancelled or no image in clipboard")
                    }
                } else {
                    print("BrainDump: Screenshot cancelled (exit code: \(process.terminationStatus))")
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            print("BrainDump: Failed to start screenshot: \(error)")
        }
    }
    
    private func startFullScreenshotCapture() {
        print("BrainDump: Starting full screenshot capture")
        
        // Use macOS screencapture for full screen
        // -c = copy to clipboard instead of file
        // -x = no sound
        // No -i flag = captures entire screen (like Cmd+Shift+3)
        
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-c", "-x"]
        
        task.terminationHandler = { [self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 0 {
                    // Small delay to ensure clipboard is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Check if there's an image in the clipboard
                        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
                            print("BrainDump: Full screenshot captured, saving...")
                            
                            if let savedItem = StorageManager.shared.saveImage(image, method: .bubbleFullScreenshot) {
                                print("BrainDump: ✅ Full screenshot saved")
                                onDrop?(savedItem)
                                onShowToast?()
                                triggerPulse()
                            } else {
                                print("BrainDump: ❌ Failed to save full screenshot")
                            }
                        } else {
                            print("BrainDump: No image found in clipboard after full screenshot")
                        }
                    }
                } else {
                    print("BrainDump: Full screenshot failed (exit code: \(process.terminationStatus))")
                }
            }
        }
        
        do {
            try task.run()
        } catch {
            print("BrainDump: Failed to start full screenshot: \(error)")
        }
    }
    
    // MARK: - Drop Handling
    
    private func handleDrop(providers: [NSItemProvider]) {
        // Close expanded state if open
        if isExpanded {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isExpanded = false
            }
        }
        
        // Trigger pulse animation
        triggerPulse()
        
        print("BrainDump: Drop received with \(providers.count) providers")
        
        for provider in providers {
            print("BrainDump: Provider types: \(provider.registeredTypeIdentifiers)")
            
            // Try URL type first (for web links)
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                print("BrainDump: Found URL type")
                loadURL(from: provider)
                return
            }
            
            // Try specific image types
            let imageTypes = [UTType.png, UTType.jpeg, UTType.tiff, UTType.bmp, UTType.gif]
            for imageType in imageTypes {
                if provider.hasItemConformingToTypeIdentifier(imageType.identifier) {
                    print("BrainDump: Found \(imageType.identifier)")
                    loadImage(from: provider, typeIdentifier: imageType.identifier)
                    return
                }
            }
            
            // Try generic image type
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                print("BrainDump: Found generic image")
                loadImage(from: provider, typeIdentifier: UTType.image.identifier)
                return
            }
            
            // Try file URL (for dragged files from Finder)
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                print("BrainDump: Found file URL")
                loadFileURL(from: provider)
                return
            }
            
            // Try text (might contain a URL)
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                print("BrainDump: Found plain text")
                loadText(from: provider, typeIdentifier: UTType.plainText.identifier)
                return
            }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
                print("BrainDump: Found UTF8 text")
                loadText(from: provider, typeIdentifier: UTType.utf8PlainText.identifier)
                return
            }
        }
        
        print("BrainDump: No suitable content found in drop")
    }
    
    // MARK: - URL Handler
    
    private func loadURL(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
            if let error = error {
                print("BrainDump: Error loading URL: \(error)")
                return
            }
            
            var url: URL?
            
            if let urlItem = item as? URL {
                url = urlItem
            } else if let string = item as? String {
                url = URL(string: string)
            } else if let data = item as? Data,
                      let string = String(data: data, encoding: .utf8) {
                url = URL(string: string)
            }
            
            guard let url = url else {
                print("BrainDump: Could not parse URL from item")
                return
            }
            
            print("BrainDump: URL detected: \(url.absoluteString)")
            
            // Format as a markdown link
            let linkText = "[\(url.absoluteString)](\(url.absoluteString))"
            
            DispatchQueue.main.async {
                if let savedItem = StorageManager.shared.saveText(linkText, method: .dragDrop) {
                    print("BrainDump: URL saved successfully")
                    onDrop?(savedItem)
                    onShowToast?()
                } else {
                    print("BrainDump: Failed to save URL")
                }
            }
        }
    }
    
    // MARK: - Image Handler
    
    private func loadImage(from provider: NSItemProvider, typeIdentifier: String) {
        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
            if let error = error {
                print("BrainDump: Error loading image data: \(error)")
                return
            }
            
            guard let data = data else {
                print("BrainDump: No data received for image")
                return
            }
            
            print("BrainDump: Received \(data.count) bytes of image data")
            
            if let image = NSImage(data: data) {
                print("BrainDump: Successfully created NSImage")
                DispatchQueue.main.async {
                    if let savedItem = StorageManager.shared.saveImage(image, method: .dragDrop) {
                        print("BrainDump: Image saved successfully")
                        onDrop?(savedItem)
                        onShowToast?()
                    } else {
                        print("BrainDump: Failed to save image")
                    }
                }
            } else {
                print("BrainDump: Failed to create NSImage from data")
            }
        }
    }
    
    // MARK: - File URL Handler
    
    private func loadFileURL(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error = error {
                print("BrainDump: Error loading file URL: \(error)")
                return
            }
            
            var url: URL?
            
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let urlItem = item as? URL {
                url = urlItem
            } else if let string = item as? String {
                url = URL(string: string)
            }
            
            guard let fileURL = url else {
                print("BrainDump: Could not get URL from item")
                return
            }
            
            print("BrainDump: File URL: \(fileURL)")
            
            // Check if it's a web URL (not a file path)
            if fileURL.scheme == "http" || fileURL.scheme == "https" {
                print("BrainDump: Detected web URL in file URL")
                let linkText = "[\(fileURL.absoluteString)](\(fileURL.absoluteString))"
                DispatchQueue.main.async {
                    if let savedItem = StorageManager.shared.saveText(linkText, method: .dragDrop) {
                        print("BrainDump: Web URL saved")
                        onDrop?(savedItem)
                        onShowToast?()
                    }
                }
                return
            }
            
            // Check if it's an image file
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "tiff", "bmp", "webp"]
            if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                if let image = NSImage(contentsOf: fileURL) {
                    DispatchQueue.main.async {
                        if let savedItem = StorageManager.shared.saveImage(image, method: .dragDrop) {
                            print("BrainDump: Image from file saved")
                            onDrop?(savedItem)
                            onShowToast?()
                        }
                    }
                    return
                }
            }
            
            // Try to save as file (saveFromFileURL already uses .dragDrop method)
            DispatchQueue.main.async {
                if let savedItem = StorageManager.shared.saveFromFileURL(fileURL) {
                    print("BrainDump: File saved")
                    onDrop?(savedItem)
                    onShowToast?()
                } else {
                    print("BrainDump: Failed to save file")
                }
            }
        }
    }
    
    // MARK: - Text Handler
    
    private func loadText(from provider: NSItemProvider, typeIdentifier: String) {
        provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
            if let error = error {
                print("BrainDump: Error loading text: \(error)")
                return
            }
            
            var text: String?
            
            if let string = item as? String {
                text = string
            } else if let data = item as? Data {
                text = String(data: data, encoding: .utf8)
            }
            
            guard let text = text, !text.isEmpty else {
                return
            }
            
            print("BrainDump: Text content: \(text.prefix(100))...")
            
            // Check if text is a URL
            if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
               url.scheme != nil && (url.scheme == "http" || url.scheme == "https" || url.scheme == "file") {
                print("BrainDump: Text is a URL, formatting as link")
                let linkText = "[\(text.trimmingCharacters(in: .whitespacesAndNewlines))](\(text.trimmingCharacters(in: .whitespacesAndNewlines)))"
                DispatchQueue.main.async {
                    if let savedItem = StorageManager.shared.saveText(linkText, method: .dragDrop) {
                        print("BrainDump: URL from text saved")
                        onDrop?(savedItem)
                        onShowToast?()
                    }
                }
                return
            }
            
            // Regular text
            DispatchQueue.main.async {
                if let savedItem = StorageManager.shared.saveText(text, method: .dragDrop) {
                    print("BrainDump: Text saved")
                    onDrop?(savedItem)
                    onShowToast?()
                }
            }
        }
    }
    
    // MARK: - Animations
    
    private func triggerPulse() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            isPulsing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPulsing = false
            }
        }
    }
    
    /// Public method to trigger pulse from external save (hotkey)
    func pulse() {
        triggerPulse()
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glass morphism background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    Color.primary.opacity(isHovering ? 0.25 : 0.15),
                                    lineWidth: isHovering ? 1.5 : 1.0
                                )
                        )
                        .shadow(color: .black.opacity(0.1), radius: isHovering ? 8 : 4, x: 0, y: 2)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    // Subtle color tint overlay
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(isHovering ? 0.2 : 0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 18
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    // Icon with color
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Text Input Popup Component

struct TextInputPopup: View {
    @Binding var text: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    
    @State private var escapeMonitor: Any?
    
    var body: some View {
        VStack(spacing: 8) {
            // Input field using AppKit text field for proper keyboard handling
            HStack(spacing: 8) {
                AppKitTextField(
                    text: $text,
                    placeholder: "Type your note...",
                    onSubmit: { closeAndSubmit() },
                    onEscape: { closeAndCancel() }
                )
                .frame(height: 24)
                
                // Submit button
                Button(action: { closeAndSubmit() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.gray.opacity(0.5)
                                : Color.purple
                        )
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            )
            .frame(width: 220)
            
            // Cancel hint
            Text("Press Esc to cancel")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Enable text input mode on the panel
            FloatingBubbleController.shared.enableTextInputMode()
        }
        .onDisappear {
            // Disable text input mode
            FloatingBubbleController.shared.disableTextInputMode()
        }
    }
    
    private func closeAndSubmit() {
        let currentText = text
        onSubmit(currentText)
    }
    
    private func closeAndCancel() {
        onCancel()
    }
}

// MARK: - AppKit TextField Wrapper for proper keyboard handling

struct AppKitTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onEscape: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = FocusableTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.onEscape = onEscape
        
        // Schedule first responder with retry logic
        // The panel needs time to become key window after app activation
        context.coordinator.scheduleFirstResponder(for: textField)
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        // Update escape handler
        if let focusable = nsView as? FocusableTextField {
            focusable.onEscape = onEscape
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AppKitTextField
        private var retryCount = 0
        private let maxRetries = 5
        
        init(_ parent: AppKitTextField) {
            self.parent = parent
        }
        
        /// Schedule becoming first responder with retry logic
        /// This ensures the text field gets focus even if the window isn't ready yet
        func scheduleFirstResponder(for textField: NSTextField) {
            retryCount = 0
            attemptFirstResponder(for: textField)
        }
        
        private func attemptFirstResponder(for textField: NSTextField) {
            // Delay to allow panel to become key window
            let delay = retryCount == 0 ? 0.15 : 0.1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak textField] in
                guard let self = self, let textField = textField else { return }
                
                // Check if window exists and is key
                guard let window = textField.window else {
                    self.retryIfNeeded(for: textField)
                    return
                }
                
                // Try to make first responder
                let success = window.makeFirstResponder(textField)
                
                if !success && self.retryCount < self.maxRetries {
                    self.retryIfNeeded(for: textField)
                }
            }
        }
        
        private func retryIfNeeded(for textField: NSTextField) {
            retryCount += 1
            if retryCount < maxRetries {
                attemptFirstResponder(for: textField)
            }
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

// Custom NSTextField that handles escape key
class FocusableTextField: NSTextField {
    var onEscape: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        if success {
            // Select all text when focused
            currentEditor()?.selectAll(nil)
        }
        return success
    }
}

// MARK: - Preview

struct FloatingBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        FloatingBubbleView()
            .padding(50)
            .background(Color.gray.opacity(0.3))
    }
}
