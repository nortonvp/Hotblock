# Hotblock

Hotblock is a native strict website blocker for macOS. Add domains, start a
strict session, and Hotblock closes matching browser tabs while playing
increasingly harsh spoken focus warnings.

The current command-line-tools build supports Safari, Google Chrome, Brave
Browser, and Arc through macOS Automation.

## Build and Open

```bash
./scripts/build-app.sh
open dist/Hotblock.app
```

The normal build check is:

```bash
swift build
```

## Important Prototype Limit

This repository currently uses a user LaunchAgent and AppleScript adapters.
The signed privileged helper, browser extensions, and automatic updater
described in [the product specification](docs/PRODUCT_SPEC.md) require a full
Xcode project, signing identity, and distribution setup.
