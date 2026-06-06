# macOS Spaces Renamer

A small native macOS menu bar app for giving local names to Desktop Spaces.

This first version does not modify Mission Control labels. It reads the local Spaces preference file to discover Desktop Spaces, stores custom names in the app's `UserDefaults`, and shows the current Space name in the menu bar.

## Run

```sh
swift run SpacesRenamer
```

The app runs as a menu bar item. Click it to open the Spaces panel and edit names inline.
Tap `Control` twice to open the Spaces panel from anywhere, then tap `Control` once more to close it. If macOS has not granted Accessibility yet, `Shift` + `Command` + `G` remains available as a fallback opener.

## Build

```sh
swift build
```

## Package

```sh
./scripts/package-app.sh
open -n dist/SpacesRenamer.app
```

Use a release build with:

```sh
CONFIGURATION=release ./scripts/package-app.sh
```

## Test

```sh
swift test
```

Tests require a working XCTest toolchain. If only Command Line Tools are selected and XCTest cannot be discovered, install/select full Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Current Scope

- Lists detected desktop Spaces in a menu bar panel.
- Shows the current desktop's local name in the menu bar.
- Shows named Spaces in the panel for quick switching and inline editing.
- Opens the Spaces panel with a global double-`Control` tap and closes it with the third tap, with `Shift` + `Command` + `G` as a fallback opener.
- Shows a small on-screen HUD when the current desktop changes.
- Stores names locally by macOS managed Space ID.
- Refreshes on Space changes and with a lightweight active-Space polling loop.

## Switching

Clicking Spaces 1-9 sends the matching Mission Control shortcut, such as `Control` + `7`. Spaces 10 and higher step from the current Space with repeated `Control` + `Left` / `Control` + `Right`, so they are slower and depend on current-Space detection. macOS may ask you to allow Spaces Renamer in **System Settings > Privacy & Security > Accessibility** before it can control Spaces with these shortcuts.

When the Spaces panel is open and no name field is being edited, press `1` through `9` to switch directly to that Space without using the mouse. Spaces 10 and higher remain clickable in the panel and use a subtle marker because they switch sequentially.

The double-`Control` opener only triggers on clean taps; the third tap in the same sequence closes the panel. Holding `Control` with another key, such as `Control` + `1`, does not open the panel. If the panel says double `Control` needs Accessibility, re-enable the app in **System Settings > Privacy & Security > Accessibility** and leave it running for a couple of seconds so it can retry.

## Known Limitations

- macOS does not expose a public API for true Mission Control Space renaming.
- The desktop list comes from `~/Library/Preferences/com.apple.spaces.plist`, which is not a stable public contract.
- Current desktop detection uses dynamically loaded private CoreGraphics symbols when available, then falls back to the plist state.
- Spaces 10 and higher require sequential switching because macOS only exposes direct shortcuts for earlier desktops.
