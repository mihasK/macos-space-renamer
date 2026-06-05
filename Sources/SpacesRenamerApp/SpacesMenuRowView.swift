import AppKit
import SpacesRenamerCore

@MainActor
final class SpacesMenuRowView: NSView {
    private let space: DesktopSpace
    private let onSwitch: (DesktopSpace) -> Void
    private let onRename: (DesktopSpace, String) -> Void

    private let containerView = NSView()
    private let numberButton = NSButton()
    private let nameField = NSTextField()
    private let currentDot = NSView()

    init(
        space: DesktopSpace,
        name: String,
        onSwitch: @escaping (DesktopSpace) -> Void,
        onRename: @escaping (DesktopSpace, String) -> Void
    ) {
        self.space = space
        self.onSwitch = onSwitch
        self.onRename = onRename

        super.init(frame: NSRect(x: 0, y: 0, width: 292, height: 42))
        setupView(name: name)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(nil)
    }

    private func setupView(name: String) {
        wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 8
        containerView.layer?.backgroundColor = backgroundColor
        addSubview(containerView)

        numberButton.translatesAutoresizingMaskIntoConstraints = false
        numberButton.title = space.numberTitle
        numberButton.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        numberButton.bezelStyle = .regularSquare
        numberButton.isBordered = false
        numberButton.wantsLayer = true
        numberButton.layer?.cornerRadius = 12
        numberButton.layer?.backgroundColor = numberBackgroundColor
        numberButton.contentTintColor = space.isCurrent ? .white : .labelColor
        numberButton.target = self
        numberButton.action = #selector(switchButtonClicked)
        numberButton.toolTip = "Switch to Space \(space.numberTitle)"
        containerView.addSubview(numberButton)

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.stringValue = name
        nameField.placeholderString = "Name this space"
        nameField.font = .systemFont(ofSize: 14, weight: name.isEmpty ? .regular : .medium)
        nameField.textColor = .labelColor
        nameField.placeholderAttributedString = NSAttributedString(
            string: "Name this space",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
        )
        nameField.isBordered = false
        nameField.isBezeled = false
        nameField.drawsBackground = false
        nameField.focusRingType = .none
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(nameFieldCommitted)
        nameField.toolTip = "Click to rename"
        containerView.addSubview(nameField)

        currentDot.translatesAutoresizingMaskIntoConstraints = false
        currentDot.wantsLayer = true
        currentDot.layer?.cornerRadius = 3
        currentDot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        currentDot.isHidden = !space.isCurrent
        containerView.addSubview(currentDot)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),

            numberButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            numberButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            numberButton.widthAnchor.constraint(equalToConstant: 28),
            numberButton.heightAnchor.constraint(equalToConstant: 24),

            nameField.leadingAnchor.constraint(equalTo: numberButton.trailingAnchor, constant: 10),
            nameField.trailingAnchor.constraint(equalTo: currentDot.leadingAnchor, constant: -10),
            nameField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            currentDot.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            currentDot.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            currentDot.widthAnchor.constraint(equalToConstant: 6),
            currentDot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    private var backgroundColor: CGColor {
        if space.isCurrent {
            return NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
        }

        return NSColor.clear.cgColor
    }

    private var numberBackgroundColor: CGColor {
        if space.isCurrent {
            return NSColor.controlAccentColor.cgColor
        }

        return NSColor.quaternaryLabelColor.withAlphaComponent(0.32).cgColor
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

extension SpacesMenuRowView: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        onRename(space, nameField.stringValue)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        commitName()
    }
}
