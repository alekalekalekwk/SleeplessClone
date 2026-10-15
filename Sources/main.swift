import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var statusMenuItem: NSMenuItem!
    var matikanMenuItem: NSMenuItem!
    var isSleepDisabled: Bool = false
    var sleepTimer: Timer?

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

        matikanMenuItem = NSMenuItem(title: "Matikan", action: #selector(turnOffAction), keyEquivalent: "m")
        matikanMenuItem.target = self
        menu.addItem(matikanMenuItem)

        let foreverItem = NSMenuItem(title: "Aktifkan selamanya", action: #selector(enableForeverAction), keyEquivalent: "")
        foreverItem.target = self
        menu.addItem(foreverItem)

        let oneHourItem = NSMenuItem(title: "Aktifkan 1 jam", action: #selector(enableOneHourAction), keyEquivalent: "")
        oneHourItem.target = self
        menu.addItem(oneHourItem)

        let threeHoursItem = NSMenuItem(title: "Aktifkan 3 jam", action: #selector(enableThreeHoursAction), keyEquivalent: "")
        threeHoursItem.target = self
        menu.addItem(threeHoursItem)

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
        matikanMenuItem.isHidden = !isSleepDisabled
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

    func activate(duration: TimeInterval?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        if setSleepDisabled(true) {
            if let duration = duration {
                let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.turnOff()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                sleepTimer = timer
            }
        }
    }

    func turnOff() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        setSleepDisabled(false)
    }

    @objc func turnOffAction() {
        turnOff()
    }

    @objc func enableForeverAction() {
        activate(duration: nil)
    }

    @objc func enableOneHourAction() {
        activate(duration: 3600)
    }

    @objc func enableThreeHoursAction() {
        activate(duration: 10800)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
