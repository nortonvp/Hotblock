# Hotblock

Hotblock is a strict website blocker for macOS. Add websites, press **Start**,
and Hotblock closes blocked browser tabs while telling you to focus.

Supported browsers: Safari, Google Chrome, Brave Browser, and Arc.

## Download

Visit the [Hotblock website](https://nortonvp.github.io/Hotblock/) or download
the [latest release](https://github.com/nortonvp/Hotblock/releases/latest/download/Hotblock.zip).

## Requirements

- macOS 14 or newer
- Apple's Command Line Tools

Install the Command Line Tools by opening Terminal and running:

```bash
xcode-select --install
```

## Build and Install

1. Open Terminal.
2. Download the project and enter its folder:

```bash
git clone https://github.com/nortonvp/Hotblock.git
cd Hotblock
```

3. Build the macOS app:

```bash
./scripts/build-app.sh
```

4. Install Hotblock in your Applications folder:

```bash
cp -R dist/Hotblock.app /Applications/
```

5. Open Hotblock:

```bash
open /Applications/Hotblock.app
```

Hotblock appears as a shield icon in the macOS menu bar.

## First Launch

Follow the setup assistant and allow:

- Notifications
- Automation access for every installed supported browser

If Automation access was denied, open:

**System Settings → Privacy & Security → Automation**

Then allow Hotblock to control your browsers.

## Use Hotblock

1. Add a domain such as `instagram.com`.
2. Press **Start**.
3. Choose how many random words will be required to stop the strict session.

To quickly add a large group of websites, open **Presets** and choose
**News**, **Social Media**, or **Entertainment**. Review the list, deselect any
websites you do not want, then press **Add**.

During a strict session, blocked tabs are closed automatically. To stop the
session, press **Stop** and correctly type the unlock words.

## Update Your Installation

Run these commands inside the Hotblock project folder:

```bash
git pull
./scripts/build-app.sh
rm -rf /Applications/Hotblock.app
cp -R dist/Hotblock.app /Applications/
open /Applications/Hotblock.app
```

Do not update while a strict session is active.

## Developer Build Check

To compile the source without creating an installable `.app`:

```bash
swift build
```

## Prototype Limit

This version uses a user LaunchAgent and AppleScript browser control. A signed
privileged helper, browser extensions, and automatic updater require a full
Xcode project, Apple signing identity, and distribution setup.
