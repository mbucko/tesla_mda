import AppKit
import QuartzCore

/// A short burst of small confetti from the status item. The overlay window is transparent and click-through.
@MainActor
final class ConfettiOverlay {
    private static let size = NSSize(width: 280, height: 220)
    private static let emitDuration: TimeInterval = 0.5
    private static let totalDuration: TimeInterval = 3.5
    private static let colors: [NSColor] = [
        NSColor(red: 0.89, green: 0.10, blue: 0.22, alpha: 1), // Tesla red
        NSColor(red: 0.95, green: 0.76, blue: 0.20, alpha: 1), // Robotaxi gold
        .white, .systemBlue, .systemGreen, .systemPink,
    ]

    private var window: NSWindow?

    func burst(from anchor: NSRect) {
        window?.close()

        let frame = NSRect(
            x: anchor.midX - Self.size.width / 2,
            y: anchor.maxY - Self.size.height,
            width: Self.size.width,
            height: Self.size.height
        )
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let emitter = makeEmitter(anchorHeight: anchor.height, in: view.bounds)
        view.layer?.addSublayer(emitter)
        window.contentView = view
        window.orderFrontRegardless()
        self.window = window

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.emitDuration) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.totalDuration) { [weak self, weak window] in
            window?.close()
            if self?.window === window { self?.window = nil }
        }
    }

    private func makeEmitter(anchorHeight: CGFloat, in bounds: CGRect) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        // Layer coordinates are y-up: emit from the status item at the top of the window.
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY - anchorHeight / 2)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: 40, height: 1)
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = Self.colors.flatMap { color in
            [Self.cell(color: color, image: Self.rectangleImage), Self.cell(color: color, image: Self.circleImage)]
        }
        return emitter
    }

    private static func cell(color: NSColor, image: CGImage?) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.color = color.cgColor
        cell.birthRate = 9
        cell.lifetime = 2.8
        cell.lifetimeRange = 0.6
        cell.velocity = 150
        cell.velocityRange = 70
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 2.2
        cell.yAcceleration = -260
        cell.spin = 3
        cell.spinRange = 6
        cell.scale = 0.6
        cell.scaleRange = 0.25
        cell.alphaSpeed = -0.3
        return cell
    }

    private static let rectangleImage = image(size: CGSize(width: 9, height: 5)) { $0.fill(CGRect(x: 0, y: 0, width: 9, height: 5)) }
    private static let circleImage = image(size: CGSize(width: 6, height: 6)) { $0.fillEllipse(in: CGRect(x: 0, y: 0, width: 6, height: 6)) }

    private static func image(size: CGSize, draw: (CGContext) -> Void) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        draw(context)
        return context.makeImage()
    }
}
