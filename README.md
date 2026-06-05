# macOS Spaces Renamer

A small native macOS menu bar app for giving local names to Desktop Spaces.

This first version does not modify Mission Control labels. It reads the local Spaces preference file to discover Desktop Spaces, stores custom names in the app's `UserDefaults`, and shows the current Space name in the menu bar.

## Run

```sh
swift run SpacesRenamer
```

The app runs as a menu bar item. Open the menu and choose **Rename Desktops...** to edit names.

## Build

```sh
swift build
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

- Lists detected desktop Spaces in the menu bar.
- Shows the current desktop's local name in the menu bar.
- Stores names locally by macOS managed Space ID.
- Refreshes on Space changes and every few seconds.

## Known Limitations

- macOS does not expose a public API for true Mission Control Space renaming.
- The desktop list comes from `~/Library/Preferences/com.apple.spaces.plist`, which is not a stable public contract.
- Space switching is intentionally not implemented yet.
