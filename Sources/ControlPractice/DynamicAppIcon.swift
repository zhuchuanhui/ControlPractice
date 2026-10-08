import AppKit
import SwiftUI

enum AppIconState {
    case ready, stimulate, rest, paused, complete

    var color: NSColor {
        switch self {
        case .ready: return .systemBlue
        case .stimulate: return .systemOrange
        case .rest: return .systemCyan
        case .paused: return .systemGray
        case .complete: return .systemGreen
        }
    }
}

final class DynamicAppIcon {
    static let shared = DynamicAppIcon()

    func update(for state: AppIconState) {
        let image = NSImage(size: NSSize(width: 512, height: 512))
        image.lockFocus()
        let canvas = NSRect(x: 0, y: 0, width: 512, height: 512)
        NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.30, alpha: 1).setFill()
        NSBezierPath(roundedRect: canvas.insetBy(dx: 8, dy: 8), xRadius: 92, yRadius: 92).fill()
        state.color.withAlphaComponent(0.95).setStroke()
        let ring = NSBezierPath(ovalIn: canvas.insetBy(dx: 112, dy: 112))
        ring.lineWidth = 30; ring.stroke()
        NSColor.white.withAlphaComponent(0.95).setFill()
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: 230, y: 185)); triangle.line(to: NSPoint(x: 230, y: 327)); triangle.line(to: NSPoint(x: 345, y: 256)); triangle.close(); triangle.fill()
        state.color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 390, y: 38, width: 84, height: 84)).fill()
        image.unlockFocus()
        NSApplication.shared.applicationIconImage = image
    }
}
