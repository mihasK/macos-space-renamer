import AppKit
import QuartzCore
import SpacesRenamerCore

@MainActor
final class SpacesSwitcherPanel: NSPanel {
    var onNumberKey: ((Int) -> Void)?
    var onClose: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleKeyDown(event) {
            return
        }

        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        guard !handleKeyDown(event) else {
            return
        }

        super.keyDown(with: event)
    }

    @discardableResult
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if firstResponder is NSTextView {
            return false
        }

        if event.keyCode == 53 {
            closePanel()
            return true
        }

        if
            event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
            let character = event.charactersIgnoringModifiers?.first,
            let number = character.wholeNumberValue,
            (1...9).contains(number)
        {
            onNumberKey?(number)
            return true
        }

        return false
    }

    override func resignKey() {
        super.resignKey()

        if isVisible {
            closePanel()
        }
    }

    func closePanel() {
        orderOut(nil)
        onClose?()
    }
}

@MainActor
final class SpacesSwitcherPanelView: NSView {
    private enum Layout {
        static let width: CGFloat = 360
        static let rowHeight: CGFloat = 38
        static let headerHeight: CGFloat = 44
        static let footerHeight: CGFloat = 52
        static let outerPadding: CGFloat = 10
        static let panelCornerRadius: CGFloat = 10
    }

    private let backgroundLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()

    init(
        spaces: [DesktopSpace],
        store: SpaceNameStore,
        globalHotKeyStatus: String,
        onSwitch: @escaping (DesktopSpace) -> Void,
        onRename: @escaping (DesktopSpace, String) -> Void,
        onManageNames: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        let rowCount = max(spaces.count, 1)
        let height = Layout.headerHeight
            + CGFloat(rowCount) * Layout.rowHeight
            + Layout.footerHeight
            + Layout.outerPadding * 2

        super.init(frame: NSRect(x: 0, y: 0, width: Layout.width, height: height))
        setupView(
            spaces: spaces,
            store: store,
            globalHotKeyStatus: globalHotKeyStatus,
            onSwitch: onSwitch,
            onRename: onRename,
            onManageNames: onManageNames,
            onRefresh: onRefresh,
            onQuit: onQuit
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool { true }

    private func setupView(
        spaces: [DesktopSpace],
        store: SpaceNameStore,
        globalHotKeyStatus: String,
        onSwitch: @escaping (DesktopSpace) -> Void,
        onRename: @escaping (DesktopSpace, String) -> Void,
        onManageNames: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        wantsLayer = true
        layer?.masksToBounds = false
        setupChromeLayers()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        addSubview(stack)

        let header = makeHeader(globalHotKeyStatus: globalHotKeyStatus)
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalToConstant: Layout.width - Layout.outerPadding * 2).isActive = true

        if spaces.isEmpty {
            let empty = NSTextField(labelWithString: "No desktops found")
            empty.font = .systemFont(ofSize: 13)
            empty.textColor = .secondaryLabelColor
            empty.alignment = .center
            empty.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: Layout.rowHeight).isActive = true
            empty.widthAnchor.constraint(equalToConstant: Layout.width - Layout.outerPadding * 2).isActive = true
        } else {
            for space in spaces {
                let row = SpaceSwitcherPanelRowView(
                    space: space,
                    name: store.name(for: space.managedSpaceID) ?? "",
                    accentColor: SpacesVisualTheme.accentColor(for: space, in: spaces),
                    onSwitch: onSwitch,
                    onRename: onRename
                )
                stack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalToConstant: Layout.width - Layout.outerPadding * 2).isActive = true
                row.heightAnchor.constraint(equalToConstant: Layout.rowHeight).isActive = true
            }
        }

        let footer = makeFooter(
            onManageNames: onManageNames,
            onRefresh: onRefresh,
            onQuit: onQuit
        )
        stack.addArrangedSubview(footer)
        footer.widthAnchor.constraint(equalToConstant: Layout.width - Layout.outerPadding * 2).isActive = true

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.outerPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.outerPadding),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.outerPadding),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.outerPadding)
        ])
    }

    override func layout() {
        super.layout()
        updateChromeLayers()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateChromeLayers()
    }

    private func setupChromeLayers() {
        backgroundLayer.startPoint = CGPoint(x: 0.12, y: 1)
        backgroundLayer.endPoint = CGPoint(x: 0.88, y: 0)
        backgroundLayer.cornerRadius = Layout.panelCornerRadius
        backgroundLayer.masksToBounds = true
        layer?.insertSublayer(backgroundLayer, at: 0)

        borderLayer.fillColor = nil
        borderLayer.lineWidth = 1.2
        layer?.addSublayer(borderLayer)

        highlightLayer.fillColor = nil
        highlightLayer.lineWidth = 0.8
        layer?.addSublayer(highlightLayer)

        updateChromeLayers()
    }

    private func updateChromeLayers() {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = Layout.panelCornerRadius
        backgroundLayer.colors = SpacesVisualTheme.panelGradientColors(appearance: effectiveAppearance)
        backgroundLayer.locations = [0.0, 0.38, 0.76, 1.0]

        let borderPath = CGPath(
            roundedRect: bounds.insetBy(dx: 0.6, dy: 0.6),
            cornerWidth: Layout.panelCornerRadius,
            cornerHeight: Layout.panelCornerRadius,
            transform: nil
        )
        borderLayer.frame = bounds
        borderLayer.path = borderPath
        borderLayer.strokeColor = SpacesVisualTheme.panelBorderColor(appearance: effectiveAppearance).cgColor

        let highlightPath = CGPath(
            roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
            cornerWidth: Layout.panelCornerRadius - 1,
            cornerHeight: Layout.panelCornerRadius - 1,
            transform: nil
        )
        highlightLayer.frame = bounds
        highlightLayer.path = highlightPath
        highlightLayer.strokeColor = NSColor.white.withAlphaComponent(isDark ? 0.10 : 0.42).cgColor
    }

    private func makeHeader(globalHotKeyStatus: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Spaces")
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor
        container.addSubview(title)

        let shortcut = NSTextField(labelWithString: globalHotKeyStatus)
        shortcut.translatesAutoresizingMaskIntoConstraints = false
        shortcut.font = .systemFont(ofSize: 11)
        shortcut.textColor = .secondaryLabelColor
        shortcut.alignment = .right
        container.addSubview(shortcut)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: Layout.headerHeight),

            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            title.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            shortcut.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            shortcut.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            shortcut.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: 12)
        ])

        return container
    }

    private func makeFooter(
        onManageNames: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let manageButton = NSButton(title: "Manage", target: nil, action: nil)
        manageButton.bezelStyle = .rounded
        manageButton.controlSize = .small
        manageButton.target = ButtonActionTarget.shared
        manageButton.action = #selector(ButtonActionTarget.performAction(_:))
        ButtonActionTarget.shared.setAction(onManageNames, for: manageButton)
        container.addSubview(manageButton)

        let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
        refreshButton.bezelStyle = .rounded
        refreshButton.controlSize = .small
        refreshButton.target = ButtonActionTarget.shared
        refreshButton.action = #selector(ButtonActionTarget.performAction(_:))
        ButtonActionTarget.shared.setAction(onRefresh, for: refreshButton)
        container.addSubview(refreshButton)

        let quitButton = NSButton(title: "Quit", target: nil, action: nil)
        quitButton.bezelStyle = .rounded
        quitButton.controlSize = .small
        quitButton.target = ButtonActionTarget.shared
        quitButton.action = #selector(ButtonActionTarget.performAction(_:))
        ButtonActionTarget.shared.setAction(onQuit, for: quitButton)
        container.addSubview(quitButton)

        [manageButton, refreshButton, quitButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: Layout.footerHeight),

            manageButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            manageButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            refreshButton.leadingAnchor.constraint(equalTo: manageButton.trailingAnchor, constant: 8),
            refreshButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            quitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            quitButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }
}

@MainActor
private final class SpaceSwitcherPanelRowView: NSView {
    private let space: DesktopSpace
    private let accentColor: NSColor
    private let onSwitch: (DesktopSpace) -> Void
    private let onRename: (DesktopSpace, String) -> Void

    private let numberButton = NSButton()
    private let nameField = NSTextField()
    private let sequentialIcon = NSImageView()

    init(
        space: DesktopSpace,
        name: String,
        accentColor: NSColor,
        onSwitch: @escaping (DesktopSpace) -> Void,
        onRename: @escaping (DesktopSpace, String) -> Void
    ) {
        self.space = space
        self.accentColor = accentColor
        self.onSwitch = onSwitch
        self.onRename = onRename

        super.init(frame: .zero)
        setupView(name: name)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setupView(name: String) {
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = backgroundColor
        layer?.borderColor = rowBorderColor
        layer?.borderWidth = rowBorderWidth
        toolTip = sequentialSwitchingTooltip

        numberButton.translatesAutoresizingMaskIntoConstraints = false
        numberButton.title = space.numberTitle
        numberButton.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        numberButton.bezelStyle = .regularSquare
        numberButton.isBordered = false
        numberButton.wantsLayer = true
        numberButton.layer?.cornerRadius = 11
        numberButton.layer?.backgroundColor = numberBackgroundColor
        numberButton.contentTintColor = numberTintColor
        numberButton.target = self
        numberButton.action = #selector(switchButtonClicked)
        numberButton.toolTip = sequentialSwitchingTooltip
        addSubview(numberButton)

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.stringValue = name
        nameField.placeholderString = space.defaultTitle
        nameField.font = .systemFont(ofSize: 13, weight: name.isEmpty ? .regular : .medium)
        nameField.isBordered = false
        nameField.isBezeled = false
        nameField.drawsBackground = false
        nameField.focusRingType = .none
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(nameFieldCommitted)
        addSubview(nameField)

        sequentialIcon.translatesAutoresizingMaskIntoConstraints = false
        sequentialIcon.image = NSImage(
            systemSymbolName: "arrow.right.circle",
            accessibilityDescription: "Sequential switching"
        )
        sequentialIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        sequentialIcon.contentTintColor = .tertiaryLabelColor
        sequentialIcon.isHidden = !usesSequentialSwitching
        sequentialIcon.toolTip = sequentialSwitchingTooltip
        addSubview(sequentialIcon)

        NSLayoutConstraint.activate([
            numberButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            numberButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            numberButton.widthAnchor.constraint(equalToConstant: 28),
            numberButton.heightAnchor.constraint(equalToConstant: 22),

            nameField.leadingAnchor.constraint(equalTo: numberButton.trailingAnchor, constant: 9),
            nameField.trailingAnchor.constraint(equalTo: sequentialIcon.leadingAnchor, constant: -8),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),

            sequentialIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            sequentialIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            sequentialIcon.widthAnchor.constraint(equalToConstant: 13),
            sequentialIcon.heightAnchor.constraint(equalToConstant: 13)
        ])
    }

    private var backgroundColor: CGColor {
        if space.isCurrent {
            return accentColor.withAlphaComponent(0.18).cgColor
        }

        if usesSequentialSwitching {
            return accentColor.withAlphaComponent(0.07).cgColor
        }

        return NSColor.clear.cgColor
    }

    private var numberBackgroundColor: CGColor {
        if space.isCurrent {
            return accentColor.cgColor
        }

        if usesSequentialSwitching {
            return accentColor.withAlphaComponent(0.22).cgColor
        }

        return accentColor.withAlphaComponent(0.16).cgColor
    }

    private var numberTintColor: NSColor {
        if space.isCurrent {
            return .white
        }

        if usesSequentialSwitching {
            return accentColor.blended(withFraction: 0.34, of: .labelColor) ?? .secondaryLabelColor
        }

        return accentColor.blended(withFraction: 0.20, of: .labelColor) ?? .labelColor
    }

    private var rowBorderColor: CGColor? {
        guard space.isCurrent else {
            return nil
        }

        return accentColor.withAlphaComponent(0.55).cgColor
    }

    private var rowBorderWidth: CGFloat {
        space.isCurrent ? 1 : 0
    }

    private var usesSequentialSwitching: Bool {
        space.desktopIndex >= 9
    }

    private var sequentialSwitchingTooltip: String? {
        guard usesSequentialSwitching else {
            return nil
        }

        return "Spaces above 9 do not have direct Control-number shortcuts, so switching uses repeated Control-Left/Right steps."
    }

    @objc private func switchButtonClicked() {
        onSwitch(space)
    }

    @objc private func nameFieldCommitted() {
        commitName()
    }

    private func commitName() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        nameField.stringValue = name
        onRename(space, name)
    }
}

extension SpaceSwitcherPanelRowView: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        onRename(space, nameField.stringValue)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        commitName()
    }
}

@MainActor
private final class ButtonActionTarget: NSObject {
    static let shared = ButtonActionTarget()

    private var actions: [ObjectIdentifier: () -> Void] = [:]

    func setAction(_ action: @escaping () -> Void, for button: NSButton) {
        actions[ObjectIdentifier(button)] = action
    }

    @objc func performAction(_ sender: NSButton) {
        actions[ObjectIdentifier(sender)]?()
        actions.removeValue(forKey: ObjectIdentifier(sender))
    }
}
