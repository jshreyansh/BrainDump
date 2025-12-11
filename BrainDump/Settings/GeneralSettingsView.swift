import SwiftUI
import ServiceManagement

struct GeneralSettingsTab: View {
    
    @AppStorage("settings.bubble.showOnLaunch") private var showBubbleOnLaunch: Bool = true
    @AppStorage("settings.bubble.position") private var bubblePosition: String = "bottom-right"
    @AppStorage("settings.selection.enabled") private var showSelectionPopup: Bool = true
    @State private var launchAtLogin: Bool = false
    @State private var storageLocation: String = ""
    @State private var showingFolderPicker = false
    @State private var hotkeyStatus: String = "Checking..."
    
    var body: some View {
        Form {
            // Floating Bubble Section
            Section {
                Toggle("Show floating bubble on launch", isOn: $showBubbleOnLaunch)
                
                Picker("Default position", selection: $bubblePosition) {
                    Text("Bottom Right").tag("bottom-right")
                    Text("Bottom Left").tag("bottom-left")
                    Text("Top Right").tag("top-right")
                    Text("Top Left").tag("top-left")
                }
                
                Button("Reset Bubble Position") {
                    FloatingBubbleController.shared.resetPosition()
                }
            } header: {
                Label("Floating Bubble", systemImage: "bubble.right")
            }
            
            // Hotkey Section
            Section {
                HStack {
                    Text("Global Hotkey")
                    Spacer()
                    Text("⌘ + ⌥ + D")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(hotkeyStatus)
                        .foregroundColor(hotkeyStatus == "Active" ? .green : .orange)
                }
                
                if hotkeyStatus != "Active" {
                    Button("Grant Accessibility Permission") {
                        HotkeyManager.requestAccessibilityPermission()
                    }
                    .foregroundColor(.accentColor)
                    
                    Text("BrainDump needs Accessibility permission to capture text with the global hotkey.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Hotkey", systemImage: "keyboard")
            }
            
            // Selection Popup Section
            Section {
                Toggle("Show capture button on text selection", isOn: $showSelectionPopup)
                    .onChange(of: showSelectionPopup) { newValue in
                        SelectionMonitor.shared.updateMonitoringState()
                    }
                
                Text("When enabled, a small \"Capture\" button appears near selected text in any app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !showSelectionPopup {
                    Text("Tip: You can still use ⌘ + ⌥ + D to capture selected text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Label("Selection Popup", systemImage: "text.cursor")
            }
            
            // Storage Section
            Section {
                HStack {
                    Text("Location")
                    Spacer()
                    Text(storageLocation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                HStack {
                    Button("Choose Folder...") {
                        showingFolderPicker = true
                    }
                    
                    Button("Reset to Default") {
                        StorageManager.shared.resetStorageLocation()
                        updateStorageLocation()
                    }
                    .foregroundColor(.secondary)
                }
                
                Button("Open Storage Folder") {
                    NSWorkspace.shared.open(StorageManager.shared.storageURL)
                }
            } header: {
                Label("Storage", systemImage: "folder")
            }
            
            // Startup Section
            Section {
                Toggle("Launch BrainDump at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            } header: {
                Label("Startup", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 450)
        .onAppear {
            updateStorageLocation()
            updateHotkeyStatus()
            updateLaunchAtLoginStatus()
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                StorageManager.shared.setStorageLocation(url)
                updateStorageLocation()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func updateStorageLocation() {
        storageLocation = StorageManager.shared.storageURL.path
    }
    
    private func updateHotkeyStatus() {
        if HotkeyManager.shared.isRegistered {
            hotkeyStatus = "Active"
        } else if HotkeyManager.checkAccessibilityPermission() {
            hotkeyStatus = "Permission granted, registering..."
            HotkeyManager.shared.register()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                hotkeyStatus = HotkeyManager.shared.isRegistered ? "Active" : "Failed to register"
            }
        } else {
            hotkeyStatus = "Needs permission"
        }
    }
    
    private func updateLaunchAtLoginStatus() {
        // Check current launch at login status
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set launch at login: \(error)")
            }
        }
    }
}

// MARK: - Preview

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsTab()
    }
}
