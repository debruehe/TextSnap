# TextSnap

A lightweight macOS menu bar app for capturing text and QR/barcodes from any area of your screen.

## Features

- **Quick Capture** — Select any region of your screen to extract text or scan barcodes
- **OCR** — Accurate text recognition using Apple's Vision framework
- **Barcode/QR Support** — Reads QR codes, Aztec, Data Matrix, Code 128/39, EAN, PDF417, and more
- **Instant Paste** — Results are automatically copied to your clipboard
- **Smart Detection** — Automatically prioritizes barcodes over text
- **Subtle Feedback** — Toast notifications confirm what was captured

## Installation

1. Download the latest release from [Releases](https://github.com/debruehe/TextSnap/releases)
2. Drag `TextSnap.app` to your Applications folder
3. Launch the app — you'll be prompted for Screen Recording permission
4. A menu bar icon will appear

## Usage

### Basic Capture

1. Press the keyboard shortcut (default: **⌘⇧2**) to start capture
2. Click and drag to select an area of the screen
3. Release to capture — the result is automatically copied to clipboard

### Move Selection

While dragging, **hold space** to move the entire selection without resizing it. Release space to resume resizing.

### Settings

Click the menu bar icon (📷) and select **Preferences** to:
- Change the keyboard shortcut
- Enable "Launch at login"
- Open Privacy & Security settings (for screen recording permission)

## Building from Source

### Prerequisites

- Xcode 15+
- macOS 14.0+

### Build Steps

```bash
# Clone the repository
git clone https://github.com/debruehe/TextSnap.git
cd TextSnap

# Build using xcodebuild
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build -project TextSnap.xcodeproj \
  -scheme TextSnap -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

# The .app is in:
# ~/Library/Developer/Xcode/DerivedData/TextSnap-*/Build/Products/Debug/TextSnap.app
```

### Install to Applications

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/TextSnap-*/Build/Products/Debug/TextSnap.app /Applications/
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧2 | Start capture (default) |
| ESC | Cancel capture |
| Space | Hold to move selection |
| ⌘Q | Quit |

## Architecture

- **Main loop** (`main.swift`, `AppDelegate.swift`) — Application lifecycle
- **Capture** (`CaptureController.swift`) — Screen capture using ScreenCaptureKit
- **Analysis** (`VisionAnalyzer.swift`) — OCR and barcode detection via Vision framework
- **UI** (`SelectionView.swift`, `ScreenCaptureOverlayWindow.swift`) — Capture overlay and selection UI
- **Preferences** (`PreferencesWindowController.swift`) — Settings and hotkey configuration
- **Hotkeys** (`HotkeyManager.swift`) — Carbon Event Manager for global shortcuts

## License

MIT License — see [LICENSE](LICENSE) for details.

## Credits

Built with Swift and Apple's Vision/ScreenCaptureKit frameworks.
