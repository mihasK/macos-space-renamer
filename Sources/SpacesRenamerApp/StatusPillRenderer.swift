import AppKit

@MainActor
enum StatusPillRenderer {
    private enum Layout {
        static let height: CGFloat = 24
        static let minWidth: CGFloat = 34
        static let maxWidth: CGFloat = 176
        static let horizontalPadding: CGFloat = 6
        static let numberDiameter: CGFloat = 18
        static let numberGap: CGFloat = 7
        static let cornerRadius: CGFloat = 7
    }

    static func image(
        numberTitle: String?,
        title: String?,
        accentColor: NSColor,
        appearance: NSAppearance?
    ) -> NSImage {
        let resolvedNumber = numberTitle?.isEmpty == false ? numberTitle : nil
        let resolvedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleTitle = resolvedTitle?.isEmpty == false ? resolvedTitle : nil
        let textAttributes = titleAttributes(accentColor: accentColor, appearance: appearance)
        let textWidth = visibleTitle.map {
            ceil(($0 as NSString).size(withAttributes: textAttributes).width)
        } ?? 0
        let contentWidth = Layout.numberDiameter
            + (visibleTitle == nil ? 0 : Layout.numberGap + textWidth)
        let width = min(
            max(Layout.minWidth, contentWidth + Layout.horizontalPadding * 2),
            Layout.maxWidth
        )
        let size = NSSize(width: width, height: Layout.height)

        return NSImage(size: size, flipped: false) { rect in
            drawBackground(in: rect, accentColor: accentColor, appearance: appearance)
            drawNumber(resolvedNumber ?? "?", in: rect, accentColor: accentColor)

            if let visibleTitle {
                drawTitle(
                    visibleTitle,
                    in: rect,
                    attributes: textAttributes
                )
            }

            return true
        }
    }

    private static func drawBackground(
        in rect: NSRect,
        accentColor: NSColor,
        appearance: NSAppearance?
    ) {
        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let bounds = rect.insetBy(dx: 1, dy: 2)
        let path = NSBezierPath(
            roundedRect: bounds,
            xRadius: Layout.cornerRadius,
            yRadius: Layout.cornerRadius
        )

        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = isDark ? 3 : 2
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(isDark ? 0.18 : 0.08)
        shadow.set()

        accentColor.withAlphaComponent(isDark ? 0.24 : 0.18).setFill()
        path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        accentColor.withAlphaComponent(isDark ? 0.72 : 0.56).setStroke()
        path.lineWidth = 1
        path.stroke()

        let inner = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            xRadius: Layout.cornerRadius - 1,
            yRadius: Layout.cornerRadius - 1
        )
        NSColor.white.withAlphaComponent(isDark ? 0.08 : 0.24).setStroke()
        inner.lineWidth = 0.7
        inner.stroke()
    }

    private static func drawNumber(
        _ numberTitle: String,
        in rect: NSRect,
        accentColor: NSColor
    ) {
        let circleRect = NSRect(
            x: Layout.horizontalPadding,
            y: rect.midY - Layout.numberDiameter / 2,
            width: Layout.numberDiameter,
            height: Layout.numberDiameter
        )
        let circle = NSBezierPath(ovalIn: circleRect)
        accentColor.setFill()
        circle.fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: numberTitle.count > 1 ? 9.8 : 10.8, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.96),
            .paragraphStyle: paragraphStyle
        ]
        let textRect = circleRect.insetBy(dx: 1, dy: 2.2)
        (numberTitle as NSString).draw(in: textRect, withAttributes: attributes)
    }

    private static func drawTitle(
        _ title: String,
        in rect: NSRect,
        attributes: [NSAttributedString.Key: Any]
    ) {
        let textX = Layout.horizontalPadding + Layout.numberDiameter + Layout.numberGap
        let textRect = NSRect(
            x: textX,
            y: rect.midY - 7.5,
            width: rect.width - textX - Layout.horizontalPadding,
            height: 16
        )
        (title as NSString).draw(in: textRect, withAttributes: attributes)
    }

    private static func titleAttributes(
        accentColor: NSColor,
        appearance: NSAppearance?
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let isDark = appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let textColor = isDark
            ? NSColor.white.withAlphaComponent(0.94)
            : accentColor.blended(withFraction: 0.34, of: .labelColor) ?? .labelColor

        return [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
    }
}
