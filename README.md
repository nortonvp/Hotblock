# Hotblock

Hotblock is a minimal macOS app starter built with SwiftUI and stored in GitHub-friendly project files.

## What is in this repo

- A native macOS app target written in Swift
- A simple starter window with a couple of working actions
- A GitHub Actions workflow that builds the app on macOS

## Open the app locally

1. Install Xcode from the Mac App Store.
2. Open this folder in Xcode.
3. Run the `Hotblock` target.

You can also build from Terminal with:

```bash
swift build
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

- Replace the starter UI with your real app idea
- Add app storage or file handling
- Add an app icon and signing later in Xcode
