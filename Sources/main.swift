import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var statusMenuItem: NSMenuItem!
    var toggleMenuItem: NSMenuItem!
    var isSleepDisabled: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()
        updateUI()
    }

    func buildMenu() {
        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Status: Off", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        toggleMenuItem = NSMenuItem(title: "Aktifkan", action: #selector(toggleAction), keyEquivalent: "t")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateUI() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: isSleepDisabled ? "moon.zzz.fill" : "moon.zzz", accessibilityDescription: nil)
        }
        statusMenuItem.title = isSleepDisabled ? "Status: On" : "Status: Off"
        toggleMenuItem.title = isSleepDisabled ? "Matikan" : "Aktifkan"
    }

    @discardableResult
    func setSleepDisabled(_ on: Bool) -> Bool {
        let scriptSource = "do shell script \"/usr/bin/pmset -a disablesleep \(on ? 1 : 0)\" with administrator privileges"
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
            if error == nil {
                isSleepDisabled = on
                updateUI()
                return true
            }
        }
        return false
    }

    @objc func toggleAction() {
        setSleepDisabled(!isSleepDisabled)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
