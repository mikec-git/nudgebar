import AppKit

enum StatusItemDotImage {
    static let size = NSSize(width: 14, height: 14)

    /// Build a template (monochrome) dot image for the proximity bucket.
    /// Template images follow the menu bar's light/dark appearance automatically.
    static func image(for proximity: StatusItemProximity) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let dotDiameter: CGFloat
            let lineWidth: CGFloat
            let filled: Bool

            switch proximity {
            case .none:
                dotDiameter = 8
                lineWidth = 1.25
                filled = false
            case .default:
                dotDiameter = 8
                lineWidth = 0
                filled = true
            case .warning:
                dotDiameter = 9
                lineWidth = 0
                filled = true
            case .urgent:
                dotDiameter = 10
                lineWidth = 0
                filled = true
            }

            let origin = NSPoint(
                x: (rect.width - dotDiameter) / 2,
                y: (rect.height - dotDiameter) / 2
            )
            let dotRect = NSRect(origin: origin, size: NSSize(width: dotDiameter, height: dotDiameter))
            let path = NSBezierPath(ovalIn: dotRect)
            NSColor.labelColor.setFill()
            NSColor.labelColor.setStroke()

            if filled {
                path.fill()
            } else {
                path.lineWidth = lineWidth
                path.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }
}
