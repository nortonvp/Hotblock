# Hotblock

Hotblock is a strict website blocker for macOS. Add websites, press **Start**,
and Hotblock closes blocked browser tabs while telling you to focus.

Supported browsers: Safari, Google Chrome, Brave Browser, and Arc.

## Download

Visit the [Hotblock website](https://hotblock.app/) or download
the [latest release](https://github.com/nortonvp/Hotblock/releases/latest/download/Hotblock.dmg).

## Install the GitHub Beta

The downloadable app requires macOS 14 or newer and works on Apple Silicon and
Intel Macs.

1. Download and open `Hotblock.dmg`.
2. Drag Hotblock into the Applications folder.
3. Right-click Hotblock and choose **Open**.
4. If macOS blocks it, open **System Settings → Privacy & Security**, scroll
   down, and click **Open Anyway**.
5. Follow Hotblock's setup assistant to allow Automation. Notifications are optional.

Hotblock is currently a free, open-source GitHub beta. GitHub Actions builds
every release directly from this repository. The app is ad-hoc signed rather
than Apple-notarized, so macOS shows a warning the first time you open it.

## Build It Yourself

Building from source requires Apple's Command Line Tools. Open Terminal and run:

```bash
xcode-select --install
git clone https://github.com/nortonvp/Hotblock.git
cd Hotblock
./scripts/build-app.sh
cp -R dist/Hotblock.app /Applications/
open /Applications/Hotblock.app
```

Hotblock appears as a shield icon in the macOS menu bar.

## Verify the Download

Each GitHub release includes `Hotblock.dmg.sha256`. To verify the disk image, download
both files into the same folder, open Terminal in that folder, and run:

```bash
shasum -a 256 -c Hotblock.dmg.sha256
```

Terminal should print `Hotblock.dmg: OK`.

## First Launch

Follow the setup assistant and allow:

- Automation access for every installed supported browser
- Notifications, if you want permission and tab-closing alerts

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
