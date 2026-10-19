import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: nil)
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        popover.behavior = .transient
        let hostingController = NSHostingController(rootView: PopoverView())
        popover.contentViewController = hostingController

        SleepController.shared.onStateChange = { [weak self] in
            self?.updateStatusIcon()
        }

        // Global hotkey toggle
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.handleHotkeyToggle()
        }

        let regOk = HotKeyManager.shared.register(
            keyCode: Settings.shared.hotkeyKeyCode,
            carbonModifiers: Settings.shared.hotkeyModifiers
        )
        if !regOk {
            PopoverState.shared.hotkeyError = "Shortcut already in use"
        }

        SleepController.shared.start()
        updateStatusIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SleepController.shared.applicationWillTerminate()
    }

    @objc func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    func showContextMenu() {
        let menu = NSMenu()
        if SleepController.shared.isSleepDisabled {
            let turnOffItem = NSMenuItem(title: "Turn off", action: #selector(turnOffMenuAction), keyEquivalent: "")
            turnOffItem.target = self
            menu.addItem(turnOffItem)
        }
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitMenuAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func turnOffMenuAction() {
        let success = SleepController.shared.deactivate()
        if success {
            HUDManager.shared.show(title: "Sleepless off")
        }
    }

    @objc func quitMenuAction() {
        SleepController.shared.quit()
    }

    func handleHotkeyToggle() {
        let controller = SleepController.shared
        let settings = Settings.shared

        if controller.isSleepDisabled {
            let success = controller.deactivate()
            if success {
                HUDManager.shared.show(title: "Sleepless off")
            }
        } else {
            let duration = (settings.mode == 0) ? settings.durationMinutes : nil
            let success = controller.activate(minutes: duration)
            if success {
                let subtitle: String
                if settings.mode == 0 {
                    subtitle = formatDurationSubtitle(duration)
                } else {
                    subtitle = "until battery \(settings.stopAtBatteryPercent)%"
                }
                HUDManager.shared.show(title: "Sleepless activated", subtitle: subtitle)
            }
        }
    }

    private func updateStatusIcon() {
        if let button = statusItem.button {
            let iconName = SleepController.shared.isSleepDisabled ? "moon.zzz.fill" : "moon.zzz"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        }
    }

    private func formatDurationSubtitle(_ minutes: Int?) -> String {
        guard let minutes = minutes else { return "Until you stop" }
        if minutes < 60 {
            return "for \(minutes) minutes"
        }
        let hours = minutes / 60
        return hours == 1 ? "for 1 hour" : "for \(hours) hours"
    }
}
