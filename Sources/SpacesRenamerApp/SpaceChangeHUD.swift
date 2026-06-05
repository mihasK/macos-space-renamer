import AppKit

@MainActor
final class SpaceChangeHUD {
    private var panel: NSPanel?
    private var titleLabel: NSTextField?
    private var hideWorkItem: DispatchWorkItem?

    func show(spaceTitle: String) {
        let panel = panel ?? makePanel()
        self.panel = panel

        titleLabel?.stringValue = spaceTitle
        position(panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.hide()
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35, execute: workItem)
    }

    private func hide() {
        guard let panel else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 74),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let container = NSView(frame: panel.contentView?.bounds ?? .zero)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor

        let caption = NSTextField(labelWithString: "Current Desktop")
        caption.font = .systemFont(ofSize: 12, weight: .medium)
        caption.textColor = .white.withAlphaComponent(0.72)
        caption.alignment = .center
        caption.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel = titleLabel

        container.addSubview(caption)
        container.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            caption.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            caption.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: caption.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18)
        ])

        panel.contentView = container
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelFrame = panel.frame
        let origin = NSPoint(
            x: frame.midX - panelFrame.width / 2,
            y: frame.maxY - panelFrame.height - 64
        )

        panel.setFrameOrigin(origin)
    }
}
