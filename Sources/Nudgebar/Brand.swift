import AppKit
import SwiftUI

/// Locked Nudgebar brand tokens (see design/brand-book.html).
enum Brand {
    static let ink = Color(brandHex: 0x2D2520)        // background
    static let inkDeep = Color(brandHex: 0x211B17)    // deeper backdrop
    static let ember = Color(brandHex: 0x3A2F28)      // surface
    static let emberRaised = Color(brandHex: 0x473A31) // raised surface
    static let blush = Color(brandHex: 0xFFD6CC)      // label / accent
    static let sand = Color(brandHex: 0xC7B6A8)       // secondary text
    static let stone = Color(brandHex: 0xA6968A)      // tertiary text
    static let rule = Color.white.opacity(0.08)
    static let ruleStrong = Color.white.opacity(0.14)

    static let inkNSColor = NSColor(srgbRed: 0x2D / 255, green: 0x25 / 255, blue: 0x20 / 255, alpha: 1)

    /// Type uses Geist in the mockups; Geist isn't bundled yet, so fall back to the
    /// system grotesque, which is the closest match. Swap to `.custom("Geist", …)`
    /// once the font is bundled.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension Color {
    init(brandHex hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum RingState {
    case idle    // four corner dots
    case active  // + center dot
    case urgent  // swollen center + halos
}

/// The Bold States Ring logo: four corner dots are constant; the center changes
/// by state. Geometry mirrors the locked SVG (viewBox 0 0 200 200).
struct RingLogo: View {
    var state: RingState = .active
    var color: Color = Brand.blush

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 200

            func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, opacity: Double = 1) {
                let rect = CGRect(x: (x - r) * unit, y: (y - r) * unit, width: 2 * r * unit, height: 2 * r * unit)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }

            if state == .urgent {
                dot(100, 100, 95, opacity: 0.06)
                dot(100, 100, 46, opacity: 0.10)
                dot(100, 100, 34, opacity: 0.20)
            }
            dot(100, 40, 14)
            dot(160, 100, 14)
            dot(100, 160, 14)
            dot(40, 100, 14)
            if state != .idle {
                dot(100, 100, state == .urgent ? 22 : 16)
            }
        }
    }

    /// Monochrome template image for the menu-bar status item (system-tinted).
    static func statusImage(state: RingState) -> NSImage? {
        let renderer = ImageRenderer(content: RingLogo(state: state, color: .black).frame(width: 17, height: 17))
        renderer.scale = 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = true
        return image
    }
}

/// `Nudgebar.` wordmark with the blush terminal period.
struct Wordmark: View {
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 1) {
            Text("Nudgebar")
                .font(Brand.font(size, .semibold))
                .foregroundStyle(Brand.sand)
            Text(".")
                .font(Brand.font(size, .semibold))
                .foregroundStyle(Brand.blush)
        }
        .kerning(-0.4)
    }
}
