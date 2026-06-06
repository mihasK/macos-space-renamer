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
    private var switcherPanel: SpacesSwitcherPanel?
    private var lastPanelCloseDate = Date.distantPast
    private var refreshTimer: Timer?
    private var openerRetryTimer: Timer?
    private var activeSpaceRefreshTimers: [Timer] = []
    private var globalHotKey: GlobalHotKey?
    private var globalHotKeyStatus = "Opener: double Control"
    private var currentManagedSpaceID: Int?
    private var completedInitialRefresh = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        configureStatusItemButton()

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

        registerGlobalHotKey()
        refresh(announceChanges: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        openerRetryTimer?.invalidate()
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
        renderSpacesPanelIfOpen()
    }

    private func registerGlobalHotKey() {
        let hotKey = GlobalHotKey { [weak self] in
            self?.toggleSpacesPanel()
        }

        globalHotKey = hotKey
        updateGlobalHotKeyStatus(hotKey.registerOpeners(promptForAccessibility: true))

        openerRetryTimer = Timer.scheduledTimer(
            timeInterval: 2,
            target: self,
            selector: #selector(openerRetryTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func openerRetryTimerFired() {
        guard let globalHotKey else {
            openerRetryTimer?.invalidate()
            openerRetryTimer = nil
            updateGlobalHotKeyStatus(.unavailable)
            return
        }

        let status = globalHotKey.registerOpeners(promptForAccessibility: false)
        updateGlobalHotKeyStatus(status)

        if status == .doubleControl {
            openerRetryTimer?.invalidate()
            openerRetryTimer = nil
        }
    }

    private func updateGlobalHotKeyStatus(_ status: GlobalHotKey.RegistrationStatus) {
        let statusText = status.displayText

        guard globalHotKeyStatus != statusText else {
            return
        }

        globalHotKeyStatus = statusText
        renderSpacesPanelIfOpen()
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
        updateStatusItemAppearance()

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

    private func renameSpace(_ space: DesktopSpace, name: String) {
        store.setName(name, for: space.managedSpaceID)
        updateStatusItemAppearance()
    }

    @objc private func toggleSpacesPanel() {
        if switcherPanel?.isVisible == true {
            closeSpacesPanel()
        } else if Date().timeIntervalSince(lastPanelCloseDate) > 0.2 {
            showSpacesPanel()
        } else {
            lastPanelCloseDate = .distantPast
        }
    }

    private func showSpacesPanel() {
        refresh(announceChanges: false)

        let panel = switcherPanel ?? SpacesSwitcherPanel()
        switcherPanel = panel
        renderSpacesPanel(panel)
        positionSpacesPanel(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func renderSpacesPanelIfOpen() {
        guard let panel = switcherPanel, panel.isVisible else {
            return
        }

        renderSpacesPanel(panel)
        positionSpacesPanel(panel)
    }

    private func renderSpacesPanel(_ panel: SpacesSwitcherPanel) {
        let view = SpacesSwitcherPanelView(
            spaces: spaces,
            store: store,
            globalHotKeyStatus: globalHotKeyStatus,
            onSwitch: { [weak self] space in
                self?.switchToSpace(space)
            },
            onRename: { [weak self] space, name in
                self?.renameSpace(space, name: name)
            },
            onManageNames: { [weak self] in
                self?.closeSpacesPanel()
                self?.openNameEditor()
            },
            onRefresh: { [weak self] in
                self?.manualRefresh()
            },
            onQuit: { [weak self] in
                self?.quit()
            }
        )

        panel.contentView = view
        panel.initialFirstResponder = view
        panel.setContentSize(view.frame.size)
        panel.makeFirstResponder(view)
        panel.onNumberKey = { [weak self] number in
            self?.switchToSpaceNumber(number)
        }
        panel.onClose = { [weak self, weak panel] in
            guard let self, let panel, self.switcherPanel === panel else {
                return
            }

            self.lastPanelCloseDate = Date()
            self.switcherPanel = nil
        }
    }

    private func closeSpacesPanel() {
        guard let panel = switcherPanel else {
            return
        }

        panel.onClose = nil
        panel.closePanel()
        lastPanelCloseDate = Date()
        switcherPanel = nil
    }

    private func positionSpacesPanel(_ panel: SpacesSwitcherPanel) {
        let panelSize = panel.frame.size
        let screen = statusItem?.button?.window?.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        guard
            let button = statusItem?.button,
            let buttonWindow = button.window
        else {
            let fallbackOrigin = NSPoint(
                x: visibleFrame.midX - panelSize.width / 2,
                y: visibleFrame.maxY - panelSize.height - 34
            )
            panel.setFrameOrigin(fallbackOrigin)
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = buttonWindow.convertToScreen(buttonFrameInWindow)
        let margin: CGFloat = 8
        var originX = buttonFrame.midX - panelSize.width / 2
        var originY = buttonFrame.minY - panelSize.height - 6

        originX = min(
            max(originX, visibleFrame.minX + margin),
            visibleFrame.maxX - panelSize.width - margin
        )

        if originY < visibleFrame.minY + margin {
            originY = buttonFrame.maxY + 6
        }

        originY = min(
            max(originY, visibleFrame.minY + margin),
            visibleFrame.maxY - panelSize.height - margin
        )

        panel.setFrame(
            NSRect(origin: NSPoint(x: originX, y: originY), size: panelSize),
            display: true
        )
    }

    private func switchToSpaceNumber(_ number: Int) {
        guard let space = spaces.first(where: { $0.desktopIndex == number - 1 }) else {
            NSSound.beep()
            return
        }

        switchToSpace(space)
    }

    private func switchToSpace(_ space: DesktopSpace) {
        closeSpacesPanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else {
                return
            }

            let currentSpace = self.currentSpace(for: space)

            switch self.switcher.switchToSpace(space, from: currentSpace) {
            case .alreadyCurrent:
                break
            case .started:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    self?.refresh(announceChanges: true)
                }
            case .needsAccessibilityPermission, .unavailable:
                NSSound.beep()
            }
        }
    }

    private func currentSpace(for targetSpace: DesktopSpace) -> DesktopSpace? {
        spaces.first { $0.isCurrent && $0.displayIndex == targetSpace.displayIndex }
            ?? spaces.first {
                $0.managedSpaceID == currentManagedSpaceID && $0.displayIndex == targetSpace.displayIndex
            }
            ?? spaces.first { $0.isCurrent }
            ?? spaces.first { $0.managedSpaceID == currentManagedSpaceID }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func currentStatusTitle() -> String {
        guard let currentSpace = currentStatusSpace() else {
            return "Spaces"
        }

        return title(for: currentSpace)
    }

    private func currentStatusSpace() -> DesktopSpace? {
        spaces.first(where: \.isCurrent)
            ?? spaces.first { $0.managedSpaceID == currentManagedSpaceID }
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

    private func configureStatusItemButton() {
        guard let button = statusItem?.button else {
            return
        }

        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.isBordered = false
        button.target = self
        button.action = #selector(toggleSpacesPanel)
        updateStatusItemAppearance()
    }

    private func updateStatusItemAppearance() {
        guard
            let statusItem,
            let button = statusItem.button
        else {
            return
        }

        let currentSpace = currentStatusSpace()
        let displayTitle = currentSpace.map { title(for: $0) } ?? "Spaces"
        let assignedTitle = currentSpace.flatMap { store.name(for: $0.managedSpaceID) }
        let accentColor = currentSpace.map {
            SpacesVisualTheme.accentColor(for: $0, in: spaces)
        } ?? SpacesVisualTheme.defaultAccentColor
        let image = StatusPillRenderer.image(
            numberTitle: currentSpace?.numberTitle,
            title: assignedTitle,
            accentColor: accentColor,
            appearance: button.effectiveAppearance
        )
        image.isTemplate = false

        button.title = ""
        button.image = image
        button.toolTip = "Current Space: \(displayTitle)"
        button.setAccessibilityLabel("Current Space: \(displayTitle)")
        statusItem.length = image.size.width + 8
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === editWindow {
            editWindow = nil
        }
    }
}
