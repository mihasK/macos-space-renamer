import AppKit
import SpacesRenamerCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let reader = SpacesPreferencesReader()
    private let liveReader = LiveSpacesReader()
    private let activeSpaceReader = ActiveSpaceReader()
    private let switcher = SpaceSwitcher()
    private let store = SpaceNameStore()
    private let hud = SpaceChangeHUD()

    private var statusItem: NSStatusItem?
    private var spaces: [DesktopSpace] = []
    private var editWindow: NSWindow?
    private var refreshTimer: Timer?
    private var activeSpaceRefreshTimers: [Timer] = []
    private var currentManagedSpaceID: Int?
    private var completedInitialRefresh = false
    private var isMenuOpen = false
    private var renderedMenuSnapshot: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Spaces"
        self.statusItem = statusItem

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )

        refreshTimer = Timer.scheduledTimer(
            timeInterval: 0.15,
            target: self,
            selector: #selector(timerRefresh),
            userInfo: nil,
            repeats: true
        )

        refresh(announceChanges: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        activeSpaceRefreshTimers.forEach { $0.invalidate() }
    }

    @objc private func activeSpaceDidChange() {
        activeSpaceRefreshTimers.forEach { $0.invalidate() }
        activeSpaceRefreshTimers.removeAll()

        for delay in [0.02, 0.08, 0.16, 0.3, 0.55] {
            let timer = Timer.scheduledTimer(
                timeInterval: delay,
                target: self,
                selector: #selector(spaceChangeRefreshTimerFired),
                userInfo: nil,
                repeats: false
            )
            activeSpaceRefreshTimers.append(timer)
        }
    }

    @objc private func spaceChangeRefreshTimerFired(_ timer: Timer) {
        activeSpaceRefreshTimers.removeAll { $0 === timer }
        refresh(announceChanges: true)
    }

    @objc private func timerRefresh() {
        refresh(announceChanges: true)
    }

    @objc private func manualRefresh() {
        refresh(announceChanges: false)
    }

    private func refresh(announceChanges: Bool) {
        let previousManagedSpaceID = currentManagedSpaceID
        let activeManagedSpaceID = activeSpaceReader.activeSpaceID()
        let matchingActiveManagedSpaceID: Int?

        spaces = readSpaces()
        matchingActiveManagedSpaceID = activeManagedSpaceID.flatMap { activeManagedSpaceID in
            spaces.contains(where: { $0.managedSpaceID == activeManagedSpaceID }) ? activeManagedSpaceID : nil
        }

        if let matchingActiveManagedSpaceID {
            spaces = spaces.map { space in
                space.markingCurrent(space.managedSpaceID == matchingActiveManagedSpaceID)
            }
        }

        currentManagedSpaceID = spaces.first(where: \.isCurrent)?.managedSpaceID ?? matchingActiveManagedSpaceID
        statusItem?.button?.title = currentStatusTitle()
        rebuildMenuIfNeeded()

        if
            completedInitialRefresh,
            announceChanges,
            let currentManagedSpaceID,
            currentManagedSpaceID != previousManagedSpaceID
        {
            announceCurrentSpaceChange()
        }

        completedInitialRefresh = true
    }

    private func readSpaces() -> [DesktopSpace] {
        if let liveSpaces = liveReader.readDesktopSpaces() {
            return liveSpaces
        }

        do {
            return try reader.readDesktopSpaces()
        } catch {
            return []
        }
    }

    @objc private func openNameEditor() {
        if let editWindow {
            editWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = SpaceNamesViewModel(
            reader: reader,
            store: store,
            onChange: { [weak self] in self?.refresh(announceChanges: false) },
            onClose: { [weak self] in self?.closeNameEditor() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Desktop Names"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SpaceNamesWindow(viewModel: viewModel))
        window.delegate = self
        editWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeNameEditor() {
        editWindow?.close()
        editWindow = nil
    }

    @objc private func renameSpaceFromMenu(_ sender: NSMenuItem) {
        openNameEditor()
    }

    private func renameSpace(_ space: DesktopSpace, name: String) {
        store.setName(name, for: space.managedSpaceID)
        statusItem?.button?.title = currentStatusTitle()
    }

    private func switchToSpace(_ space: DesktopSpace) {
        statusItem?.menu?.cancelTracking()

        if switcher.switchToSpace(space) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.refresh(announceChanges: true)
            }
        } else {
            NSSound.beep()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func rebuildMenuIfNeeded(force: Bool = false) {
        guard !isMenuOpen else {
            return
        }

        let snapshot = menuSnapshot()

        guard force || snapshot != renderedMenuSnapshot else {
            return
        }

        rebuildMenu()
        renderedMenuSnapshot = snapshot
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        if spaces.isEmpty {
            let item = NSMenuItem(title: "No desktops found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let spaceGroups = groupedSpaces()

            for group in spaceGroups {
                if spaceGroups.count > 1 {
                    let displayItem = NSMenuItem(
                        title: displayTitle(for: group.displayIdentifier, index: group.displayIndex),
                        action: nil,
                        keyEquivalent: ""
                    )
                    displayItem.isEnabled = false
                    menu.addItem(displayItem)
                }

                for space in group.spaces {
                    let item = NSMenuItem()
                    item.view = SpacesMenuRowView(
                        space: space,
                        name: store.name(for: space.managedSpaceID) ?? "",
                        onSwitch: { [weak self] space in
                            self?.switchToSpace(space)
                        },
                        onRename: { [weak self] space, name in
                            self?.renameSpace(space, name: name)
                        }
                    )
                    item.representedObject = space.managedSpaceID
                    menu.addItem(item)
                }
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Manage Names...", action: #selector(openNameEditor), keyEquivalent: ","))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(manualRefresh), keyEquivalent: "r"))
        menu.items.last?.target = self
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Spaces Renamer", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self

        statusItem?.menu = menu
    }

    private func menuSnapshot() -> String {
        spaces
            .sorted { lhs, rhs in
                if lhs.displayIndex == rhs.displayIndex {
                    return lhs.desktopIndex < rhs.desktopIndex
                }

                return lhs.displayIndex < rhs.displayIndex
            }
            .map { space in
                [
                    space.displayIdentifier,
                    "\(space.managedSpaceID)",
                    "\(space.desktopIndex)",
                    space.isCurrent ? "current" : "",
                    store.name(for: space.managedSpaceID) ?? ""
                ].joined(separator: ":")
            }
            .joined(separator: "|")
    }

    private func groupedSpaces() -> [(displayIdentifier: String, displayIndex: Int, spaces: [DesktopSpace])] {
        let grouped = Dictionary(grouping: spaces, by: { $0.displayIndex })

        return grouped.keys.sorted().map { displayIndex in
            let displaySpaces = grouped[displayIndex, default: []].sorted { $0.desktopIndex < $1.desktopIndex }
            let displayIdentifier = displaySpaces.first?.displayIdentifier ?? "Display \(displayIndex + 1)"
            return (displayIdentifier, displayIndex, displaySpaces)
        }
    }

    private func currentStatusTitle() -> String {
        guard let currentSpace = spaces.first(where: \.isCurrent) else {
            return "Spaces"
        }

        return title(for: currentSpace)
    }

    private func announceCurrentSpaceChange() {
        guard let currentManagedSpaceID else {
            return
        }

        if let currentSpace = spaces.first(where: { $0.managedSpaceID == currentManagedSpaceID }) {
            hud.show(spaceTitle: title(for: currentSpace))
        } else {
            hud.show(spaceTitle: "Space \(currentManagedSpaceID)")
        }
    }

    private func title(for space: DesktopSpace) -> String {
        store.name(for: space.managedSpaceID) ?? space.numberTitle
    }

    private func displayTitle(for identifier: String, index: Int) -> String {
        identifier == "Main" ? "Main Display" : "Display \(index + 1)"
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === editWindow {
            editWindow = nil
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        renderedMenuSnapshot = nil
        refresh(announceChanges: false)
    }
}
