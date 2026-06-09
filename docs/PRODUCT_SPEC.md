# Hotblock Product Specification

## Product Promise

Hotblock is a strict, website-only focus blocker for macOS. The user adds
domains, starts a strict session, and Hotblock closes matching browser tabs
while speaking increasingly harsh focus warnings.

The first full version supports Safari, Google Chrome, Brave Browser, and Arc.
Application blocking is explicitly out of scope for this version.

## Core Flow

1. The user adds one or more website domains.
2. The user presses Start.
3. Hotblock verifies that every installed supported browser can be controlled.
4. The user chooses between 1 and 100 random unlock words.
5. A strict session starts and survives sleep, app closure, and Mac restarts.
6. When a blocked domain or any of its subdomains is opened, Hotblock closes
   the tab immediately and then plays a spoken warning.
7. The user ends the session by correctly typing the original unlock words or
   by completing Administrator Recovery.

## Strict Session Rules

- Sessions have no timer and end only through an unlock action.
- Websites may be added while a session is active.
- Websites may not be removed while a session is active.
- Voice and volume settings may not be changed while a session is active.
- The normal Quit menu item remains visible but is disabled while active.
- Closing the main window keeps Hotblock running.
- Force quitting the UI causes the background protection component to relaunch
  Hotblock and restore the active session.
- On login, manual launch, or a strict-session relaunch, the main window opens.
- Sleep and wake resume monitoring silently.
- Closed blocked tabs are never restored by Hotblock.

An administrator always retains ultimate control of the Mac and can manually
remove installed components. Hotblock must never claim to be impossible for an
administrator to remove.

## Website Matching and Enforcement

- Input is normalized to a bare lowercase domain.
- Paths, schemes, ports, and a leading `www.` are removed.
- Invalid domains are rejected with a brief message.
- Duplicate domains are not added and produce a brief message.
- A configured domain matches the entire domain and all subdomains.
- Unknown, offline, or loading pages are retried silently.
- If a blocked tab does not close, Hotblock keeps trying and sends repeated
  macOS notifications.
- If browser permission is lost, Hotblock sends repeated notifications until
  permission is restored.

## Spoken Warnings

- The user chooses an installed English voice and volume before a session.
- All blocked attempts share one escalation level.
- Escalation resets after 30 minutes without a blocked attempt.
- Warnings become increasingly harsh and may be strongly insulting.
- Warnings must never contain slurs or threats.
- Warning messages are built into the app.

## Unlock and Recovery

- Start presents a slider from 1 to 100 words.
- The same generated words remain in use for the entire session.
- All words are visible on the unlock screen but cannot be selected or copied.
- Incorrect input shows an error and allows an immediate retry with the same
  words.
- A visible Administrator Recovery action invokes macOS administrator
  authentication, ends the session on success, and creates a local history
  entry.

## Interface

- The main window is fixed-size and uses standard macOS controls without custom
  visual styling.
- The main screen contains the alphabetical website list, add control,
  Start/Stop button, history icon, and settings icon.
- The top-bar shield is always visible while Hotblock runs.
- Clicking the shield opens a menu containing Open Hotblock, Blocking
  active/inactive, and Quit Hotblock.
- Only one Hotblock main window may exist.

## History and Settings

- History is local and retained until manually deleted.
- A blocked-attempt entry contains only a timestamp and website.
- History can be viewed and deleted during an active session.
- Settings contain the English voice and volume controls.

## First-Run Setup

Hotblock presents a step-by-step assistant for:

1. Background protection installation.
2. Permission for each installed supported browser.
3. macOS notification permission.
4. English voice and volume selection.
5. Final verification.

If setup is incomplete, the assistant reopens on every launch and strict
sessions cannot start. When macOS has permanently denied a prompt, Hotblock
guides the user to System Settings.

## Updates

- Production releases use automatic updates.
- An update that requires restart waits until the strict session has ended.

## Production Architecture

The shipping app requires a signed Xcode project with these components:

- `Hotblock.app`: SwiftUI/AppKit user interface and status item.
- `HotblockHelper`: privileged, signed background helper installed with
  Service Management. It persists strict-session enforcement and relaunches the
  UI after Force Quit.
- Browser enforcement adapters or extensions for Safari, Chrome, Brave, and
  Arc. Extensions are preferred over polling for production reliability.
- A local signed state file shared by the app and helper.
- A signed automatic-update framework such as Sparkle.

The command-line-tools build in this repository cannot ship a privileged
helper, browser extensions, or signed automatic updates. Until the full Xcode
targets exist, the repository uses AppleScript browser adapters and a user
LaunchAgent as an explicitly temporary enforcement layer.

## Acceptance Criteria

- A strict session and website list survive app relaunch.
- Opening a blocked domain in every permitted installed browser closes its tab,
  records history, and plays a warning.
- A second attempt escalates the shared warning level.
- Force quitting during a session relaunches the app and resumes blocking.
- The status shield remains clickable and opens the required menu.
- Opening Hotblock repeatedly never creates more than one main window.
- The normal Quit action cannot end an active strict session.
- Correct unlock words end the session; incorrect words do not.
- Existing saved settings from the prototype are migrated.
