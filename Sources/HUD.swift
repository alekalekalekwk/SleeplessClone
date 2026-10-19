import AppKit
import SwiftUI

@MainActor
final class HUDManager {
    static let shared = HUDManager()
    private var panel: NSPanel?
    private var timer: Timer?

    private init() {}

    func show(title: String, subtitle: String? = nil) {
        panel?.close()
        timer?.invalidate()

        let hudView = HUDContentView(title: title, subtitle: subtitle)
        let hostingView = NSHostingView(rootView: hudView)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = false
        newPanel.level = .statusBar
        newPanel.ignoresMouseEvents = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.maskImage = maskImage(size: NSSize(width: 240, height: 120), cornerRadius: 22)
        effectView.frame = NSRect(x: 0, y: 0, width: 240, height: 120)

        hostingView.frame = effectView.bounds
        effectView.addSubview(hostingView)
        newPanel.contentView = effectView

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen = screen {
            let x = screen.frame.origin.x + (screen.frame.width - 240) / 2
            let y = screen.frame.origin.y + (screen.frame.height - 120) / 2
            newPanel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        newPanel.alphaValue = 0
        newPanel.makeKeyAndOrderFront(nil)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            newPanel.alphaValue = 1
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                newPanel.animator().alphaValue = 1
            }
        }

        self.panel = newPanel
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fadeOut()
            }
        }
    }

    private func fadeOut() {
        guard let p = panel else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            p.close()
            self.panel = nil
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                p.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    p.close()
                    if self.panel === p {
                        self.panel = nil
                    }
                }
            })
        }
    }

    private func maskImage(size: NSSize, cornerRadius: CGFloat) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.set()
            path.fill()
            return true
        }
        return image
    }
}

struct HUDContentView: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(width: 240, height: 120)
    }
}
