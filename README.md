# Hotblock

Hotblock is a native macOS focus app for one simple job:

- add websites to a list
- click `Start`
- when one of those websites is visited, play a voice warning telling you to focus

## What is in this repo

- A native macOS SwiftUI app
- A simple website list UI
- Start and stop blocking state
- Spoken warning behavior with automatic browser checking
- A script that builds an openable `.app` bundle

## Open the app locally

1. Install Xcode from the Mac App Store.
2. Open this folder in Xcode.
3. Run the `Hotblock` target.

You can also build from Terminal with:

```bash
swift build
```

To build a normal macOS app bundle you can open from Finder:

```bash
./scripts/build-app.sh
open dist/Hotblock.app
```

## Current scope

The app now supports the core flow and checks the frontmost Safari, Chrome, Brave, or Arc tab while blocking is active.

On first use, macOS may ask you to allow Hotblock to control the browser through Automation permissions.
