# BrainDump

A powerful macOS app for quick capture and organization of text and images. BrainDump helps you instantly save snippets, screenshots, and notes directly from anywhere on your Mac with a simple hotkey or selection.

## Features

- **🔄 Quick Clipboard Capture** - Instantly capture text or images from your clipboard
- **⌨️ Global Hotkey Support** - Use ⌘⌥D (Command + Option + D) to capture selected content from anywhere
- **🎯 Text Selection Monitoring** - Automatically detect when you select text and show a capture button
- **💬 Floating Bubble Interface** - A floating bubble window for quick text input and capture actions
- **📅 Date-Based Organization** - All captures are automatically organized by date in folders
- **🖼️ Image & Text Support** - Capture both text snippets and images (PNG format)
- **📝 Rich Metadata Tracking** - Each capture includes metadata (timestamp, source app, capture method)
- **📂 Local File Storage** - All data is stored locally on your Mac (default: `~/Library/Application Support/BrainDumpAI/`)
- **🖱️ Drag & Drop** - Drop files directly into the app to capture them
- **🎛️ Menu Bar Integration** - Quick access via menu bar icon
- **⚙️ Customizable Settings** - Configure storage location and selection monitoring preferences
- **🔍 Search & Browse** - Easy browsing by date with a clean timeline interface

## How to Run

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 14.0 or later
- Swift 5.7 or later

### Building from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/jshreyansh/BrainDump.git
   cd BrainDump
   ```

2. **Open in Xcode**
   ```bash
   open BrainDump.xcodeproj
   ```

3. **Build and Run**
   - Select your target device (Mac) from the scheme selector
   - Press `⌘R` (Command + R) or click the Run button
   - Xcode will compile and launch the app

4. **Enable Accessibility Permission**
   - On first launch, macOS will prompt you to grant accessibility permissions
   - This is required for:
     - Global hotkey detection (⌘⌥D)
     - Text selection monitoring across applications
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Make sure **BrainDump** is enabled

### Alternative: Build from Command Line

```bash
xcodebuild -project BrainDump.xcodeproj -scheme BrainDump -configuration Release
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/BrainDump-*/Build/Products/Release/`

## How to Use

### First Launch

1. **Grant Permissions**: When you first launch BrainDump, you'll be prompted to grant Accessibility permissions. This is required for:
   - Global hotkey support (⌘⌥D)
   - Text selection monitoring

2. **The Floating Bubble**: A floating bubble will appear in the bottom-right corner of your screen. You can drag it anywhere you like.

3. **Main Window**: The main window shows your captures organized by date. Today's date is automatically selected.

### Capturing Content

#### Method 1: Global Hotkey (Recommended)
1. Select any text or image on your screen
2. Press **⌘⌥D** (Command + Option + D)
3. BrainDump will automatically copy and save the selected content
4. A toast notification confirms the capture

#### Method 2: Text Selection Monitoring
1. Simply select any text (3+ characters) in any application
2. A capture button will appear near your cursor
3. Click the button to save the selected text
4. The popover will automatically disappear

#### Method 3: Clipboard Capture
1. Copy any text or image to your clipboard (⌘C)
2. Click the **+** button in the floating bubble, or
3. Use the menu bar icon → "Capture from Clipboard", or
4. Press **⇧⌘V** (Shift + Command + V) in the main window

#### Method 4: Floating Bubble
1. Click the floating bubble to expand it
2. Click **+** to quickly type and save a note
3. Use **📋** to capture from clipboard
4. Use **⌨️** to start text input mode

#### Method 5: Drag & Drop
1. Drag any text file, image file, or selected text
2. Drop it onto the BrainDump main window
3. The content will be automatically saved

### Viewing Your Captures

- **By Date**: Use the left sidebar to browse captures by date (newest first)
- **Timeline View**: The right panel shows all captures for the selected date
- **Open in System App**: Double-click any capture to open it in the default app
- **Reveal in Finder**: Right-click any capture → "Reveal in Finder"

### Managing Captures

- **Delete**: Right-click any capture → "Delete"
- **Refresh**: Press **⌘R** or click the refresh button (↻) in the toolbar
- **Open Storage Folder**: Press **⇧⌘O** to open the storage folder in Finder

### Settings

Access settings via:
- Menu bar icon → Settings
- Keyboard shortcut: **⌘,**

Configure:
- **Storage Location**: Choose where to save your captures (default: `~/Library/Application Support/BrainDumpAI/`)
- **Selection Monitoring**: Enable/disable automatic text selection detection

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **⌘⌥D** | Capture selected content (global hotkey) |
| **⇧⌘V** | Capture from clipboard |
| **⇧⌘B** | Toggle floating bubble |
| **⇧⌘O** | Open storage folder |
| **⌘R** | Refresh captures |
| **⌘,** | Open Settings |

## Privacy

**🔒 BrainDump runs entirely locally on your Mac.**

- All captured content is stored in local files on your computer
- No data is sent to external servers
- No network connections are made
- No analytics or tracking
- All metadata and captures remain on your device
- Default storage location: `~/Library/Application Support/BrainDumpAI/`

You have full control over your data. You can:
- View all files directly in Finder
- Change the storage location in Settings
- Delete captures at any time
- Export or backup your captures manually

**Required Permissions:**
- **Accessibility**: Required for global hotkey detection and text selection monitoring across applications. This permission is only used locally on your Mac.

## Support

For support, bug reports, or feature requests, please contact:

**Email**: jshreyansh34@gmail.com

---

**Made with ❤️ for macOS**


