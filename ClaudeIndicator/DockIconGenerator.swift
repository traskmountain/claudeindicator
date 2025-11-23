import Cocoa
import AppKit

class DockIconGenerator {
    static func createIcon(isAsking: Bool) -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw background circle
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let circlePath = NSBezierPath(ovalIn: rect.insetBy(dx: 20, dy: 20))

        // Set color based on state
        let color = isAsking ? NSColor.systemRed : NSColor.systemGreen
        color.setFill()
        circlePath.fill()

        // Add subtle border
        NSColor.white.withAlphaComponent(0.3).setStroke()
        circlePath.lineWidth = 8
        circlePath.stroke()

        // Add a small "C" symbol in the center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 280, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]

        let text = "C" as NSString
        let textSize = text.size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 20,
            width: textSize.width,
            height: textSize.height
        )

        text.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()

        return image
    }
}
