# Hush

**Invisible AI text correction for macOS**

Hush is a lightweight menu bar app that silently watches what you type, detects when you pause, and automatically corrects your text using AI. No buttons to press, no shortcuts to remember — just type naturally and let Hush handle the rest.

<!-- ![Hush Screenshot](screenshot.png) -->

## How It Works

1. **Monitors keystrokes** globally via macOS accessibility events
2. **Detects a pause** in your typing (configurable delay, default 2s)
3. **Reads the focused text field** using the macOS Accessibility API (`AXUIElement`)
4. **Sends text to AI** for correction via the OpenRouter API (HTTPS)
5. **Replaces the text** in place — seamlessly, invisibly

Your original text is always backed up to the clipboard before any correction.

## Features

- **French & English auto-detection** — writes in whatever language you're using
- **Menu bar app** — lives in your menu bar, stays out of your way
- **Multiple correction modes** — Correction, Reformulation, or Custom Prompt
- **Clipboard backup** — original text is saved to clipboard before each correction
- **Privacy-first** — no intermediary server; text goes directly from your Mac to the OpenRouter API over HTTPS
- **Configurable** — adjust pause delay, minimum word count, correction mode, and custom prompts

## Requirements

- macOS 13 (Ventura) or later
- Accessibility permission (System Settings > Privacy & Security > Accessibility)
- An [OpenRouter](https://openrouter.ai/) API key

## Setup

### API Key Configuration

> **Important:** You must configure your own OpenRouter API key. Open the app's settings from the menu bar and enter your key. You can get one at [openrouter.ai/keys](https://openrouter.ai/keys).

### Build from Source

```bash
# Clone the repository
git clone https://github.com/Prodevking1/Hush.git
cd Hush

# Build with Swift Package Manager
swift build -c release

# Create the .app bundle
mkdir -p build/Hush.app/Contents/MacOS
mkdir -p build/Hush.app/Contents/Resources
cp .build/release/Hush build/Hush.app/Contents/MacOS/
cp Sources/Hush/Info.plist build/Hush.app/Contents/
cp Sources/Hush/AppIcon.icns build/Hush.app/Contents/Resources/

# Launch
open build/Hush.app
```

On first launch, macOS will prompt you to grant Accessibility permission.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9 |
| UI Framework | AppKit (menu bar), SwiftUI (settings & onboarding) |
| Text Access | macOS Accessibility API (`AXUIElement`) |
| Keystroke Monitoring | `CGEvent` tap |
| AI Backend | [OpenRouter API](https://openrouter.ai/) — Ministral 3B |
| Package Manager | Swift Package Manager |

## Project Structure

```
Hush/
├── Package.swift
├── Sources/Hush/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar setup & lifecycle
│   ├── AppSettings.swift       # User preferences (ObservableObject)
│   ├── KeystrokeMonitor.swift  # Global keystroke event tap
│   ├── FocusedTextReader.swift # AXUIElement text field reader
│   ├── CorrectionEngine.swift  # OpenRouter API integration
│   ├── TextReplacer.swift      # In-place text replacement
│   ├── CorrectionMode.swift    # Correction/Reformulation/Custom
│   ├── SettingsWindow.swift    # SwiftUI settings panel
│   ├── OnboardingView.swift    # First-launch onboarding
│   └── Log.swift               # Logging utilities
├── landing/                    # Marketing website
└── license-server/             # Cloudflare Worker license server
```

## License

MIT License — see [LICENSE](LICENSE) for details.

Copyright (c) 2026 Abdoul Rachid Tapsoba
