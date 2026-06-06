import AppKit
import SpacesRenamerCore

@MainActor
enum SpacesVisualTheme {
    static let defaultAccentColor = NSColor(
        calibratedRed: 0.29,
        green: 0.68,
        blue: 1.0,
        alpha: 1.0
    )

    private static let gradientStops: [(position: CGFloat, color: NSColor)] = [
        (0.00, NSColor(calibratedRed: 0.07, green: 0.28, blue: 0.78, alpha: 1.0)),
        (0.34, NSColor(calibratedRed: 0.50, green: 0.74, blue: 0.97, alpha: 1.0)),
        (0.66, NSColor(calibratedRed: 0.99, green: 0.86, blue: 0.37, alpha: 1.0)),
        (1.00, NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.38, alpha: 1.0))
    ]

    static func accentColor(for space: DesktopSpace, in spaces: [DesktopSpace]) -> NSColor {
        let orderedSpaces = spaces.sorted { lhs, rhs in
            if lhs.displayIndex == rhs.displayIndex {
                return lhs.desktopIndex < rhs.desktopIndex
            }

            return lhs.displayIndex < rhs.displayIndex
        }
        let index = orderedSpaces.firstIndex(where: { $0.managedSpaceID == space.managedSpaceID }) ?? space.desktopIndex
        let denominator = max(orderedSpaces.count - 1, 1)
        return color(at: CGFloat(index) / CGFloat(denominator))
    }

    static func color(at position: CGFloat) -> NSColor {
        let position = min(max(position, 0), 1)

        guard let first = gradientStops.first, let last = gradientStops.last else {
            return defaultAccentColor
        }

        if position <= first.position {
            return first.color
        }

        for stopIndex in 1..<gradientStops.count {
            let previous = gradientStops[stopIndex - 1]
            let next = gradientStops[stopIndex]

            guard position <= next.position else {
                continue
            }

            let span = max(next.position - previous.position, 0.001)
            let fraction = (position - previous.position) / span
            return interpolate(from: previous.color, to: next.color, fraction: fraction)
        }

        return last.color
    }

    static func panelGradientColors(appearance: NSAppearance) -> [CGColor] {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let base = NSColor.windowBackgroundColor
        let positions: [CGFloat] = [0.10, 0.50, 0.82, 1.0]

        return positions.map { position in
            let color = color(at: position)
            let blendFraction: CGFloat = isDark ? 0.80 : 0.88
            return color.blended(withFraction: blendFraction, of: base)?
                .withAlphaComponent(isDark ? 0.96 : 0.98)
                .cgColor
                ?? base.cgColor
        }
    }

    static func panelBorderColor(appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return defaultAccentColor.blended(withFraction: isDark ? 0.34 : 0.42, of: .systemBlue)?
            .withAlphaComponent(isDark ? 0.74 : 0.62)
            ?? NSColor.systemBlue.withAlphaComponent(0.60)
    }

    private static func interpolate(from start: NSColor, to end: NSColor, fraction: CGFloat) -> NSColor {
        let startColor = start.usingColorSpace(.deviceRGB) ?? start
        let endColor = end.usingColorSpace(.deviceRGB) ?? end
        let fraction = min(max(fraction, 0), 1)

        return NSColor(
            calibratedRed: startColor.redComponent + (endColor.redComponent - startColor.redComponent) * fraction,
            green: startColor.greenComponent + (endColor.greenComponent - startColor.greenComponent) * fraction,
            blue: startColor.blueComponent + (endColor.blueComponent - startColor.blueComponent) * fraction,
            alpha: startColor.alphaComponent + (endColor.alphaComponent - startColor.alphaComponent) * fraction
        )
    }
}
