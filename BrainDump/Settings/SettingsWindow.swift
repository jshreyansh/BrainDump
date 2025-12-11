import SwiftUI

struct SettingsWindow: View {

    private enum Tabs: Hashable {
        case general
        case about
    }

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            
            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tabs.about)
        }
        .frame(minWidth: 450, minHeight: 400)
    }
    
    /// Show settings programmatically
    static func show() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

// MARK: - About Settings Tab

struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // App Name
            Text("BrainDump AI")
                .font(.title)
                .fontWeight(.bold)
            
            // Version
            Text("Version \(Bundle.main.version) (\(Bundle.main.buildVersion))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Description
            Text("Zero-friction capture tool for macOS")
                .font(.body)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Hotkey info
            VStack(spacing: 8) {
                Text("Quick Capture")
                    .font(.headline)
                
                HStack {
                    Text("Select text anywhere, then press")
                    Text("⌘ + ⌥ + D")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Copyright
            Text(Bundle.main.copyright)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

struct SettingsWindow_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWindow()
    }
}
