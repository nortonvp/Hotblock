# Hotblock

Hotblock is a native macOS focus timer built with SwiftUI and stored in GitHub-friendly project files.

## What is in this repo

- A native macOS app target written in Swift
- A real first-pass focus timer UI with start, pause, reset, and duration controls
- A GitHub Actions workflow that builds the app on macOS

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

## Push to GitHub

If you have already created an empty GitHub repository, connect it with:

```bash
git remote add origin https://github.com/YOUR_USERNAME/hotblock.git
git add .
git commit -m "Initial macOS app starter"
git push -u origin main
```

## Good next steps

- Save session history with `AppStorage` or a local file
- Add notifications when a focus block finishes
- Add an app icon and signing later in Xcode
