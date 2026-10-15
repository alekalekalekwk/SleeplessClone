import AppKit
import SwiftUI

@MainActor
final class HUDManager {
    static let shared = HUDManager()
    private var panel: NSPanel?
    private var timer: Timer?

    private init() {}

    func show(active: Bool, duration: String? = nil) {
        panel?.close()
        timer?.invalidate()

        let hudView = HUDView(active: active, duration: duration)
        let hostingView = NSHostingView(rootView: hudView)

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 130),
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
        effectView.maskImage = maskImage(size: NSSize(width: 240, height: 130), cornerRadius: 20)
        effectView.frame = NSRect(x: 0, y: 0, width: 240, height: 130)

        hostingView.frame = effectView.bounds
        effectView.addSubview(hostingView)
        newPanel.contentView = effectView

        // Center on screen with mouse
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let screen = screen {
            let x = screen.frame.origin.x + (screen.frame.width - 240) / 2
            let y = screen.frame.origin.y + (screen.frame.height - 130) / 2
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
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fadeOut()
            }
        }
    }

    private func fadeOut() {
        guard let panel = panel else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if reduceMotion {
            panel.close()
            self.panel = nil
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.close()
                if self.panel === panel { self.panel = nil }
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

struct HUDView: View {
    let active: Bool
    let duration: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            if active {
                VStack(spacing: 2) {
                    Text("Sleepless activated for:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(duration ?? "Until you stop")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            } else {
                Text("Sleepless off")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding(16)
        .frame(width: 240, height: 130)
    }
}
