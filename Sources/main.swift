import AppKit
import Foundation
import IOKit.ps

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var statusMenuItem: NSMenuItem!
    var matikanMenuItem: NSMenuItem!
    var isSleepDisabled: Bool = false
    var sleepTimer: Timer?
    var batteryTimer: Timer?
    var automaticTurnOffRetryScheduled: Bool = false
    var automaticTurnOffAlertShown: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()

        // Read current state via pmset -g read
        isSleepDisabled = readSleepDisabledState()
        updateUI()

        // Battery check every 60s using IOKit.ps
        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkBatterySafety()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isSleepDisabled {
            setSleepDisabled(false)
        }
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

    func readSleepDisabledState() -> Bool {
        // pmset -g read
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.localizedCaseInsensitiveContains("SleepDisabled") {
                        if trimmed.hasSuffix("1") || trimmed.contains(" 1") {
                            return true
                        }
                    }
                }
            }
        } catch {
            return false
        }
        return false
    }

    func checkBatterySafety() {
        guard isSleepDisabled else { return }
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] {
                let state = desc[kIOPSPowerSourceStateKey] as? String
                let isAC = (state == kIOPSACPowerValue)
                if !isAC,
                   let current = desc[kIOPSCurrentCapacityKey] as? Int,
                   let max = desc[kIOPSMaxCapacityKey] as? Int,
                   max > 0 {
                    let percent = Double(current) / Double(max) * 100.0
                    if percent <= 20.0 {
                        automaticTurnOff()
                        break
                    }
                }
            }
        }
    }

    // User‑initiated AppleScript fallback (allows password prompt)
    func setSleepDisabledUser(_ on: Bool) -> Bool {
        let scriptSource = "do shell script \"/usr/bin/pmset -a disablesleep \(on ? 1 : 0)\" with administrator privileges"
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(&error)
            if error == nil {
                return true
            }
        }
        return false
    }

    @discardableResult
    func setSleepDisabledManual(_ on: Bool) -> Bool {
        if trySudoSetSleep(on) {
            isSleepDisabled = on
            updateUI()
            return true
        }
        if setSleepDisabledUser(on) {
            isSleepDisabled = on
            updateUI()
            return true
        }
        return false
    }

    @discardableResult
    func setSleepDisabled(_ on: Bool) -> Bool {
        // Try passwordless sudo first
        let result = trySudoSetSleep(on)
        if result {
            isSleepDisabled = on
            updateUI()
            return true
        }
        // No sudo; automatic actions give up (no prompt)
        return false
    }

    // Helper for sudo invocation (synchronous, no UI block)
    func trySudoSetSleep(_ on: Bool) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        proc.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", on ? "1" : "0"]
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    func activateManual(duration: TimeInterval?) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        if setSleepDisabledManual(true) {
            if let duration = duration {
                let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.automaticTurnOff()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                sleepTimer = timer
            }
        }
    }

    func automaticTurnOff() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        let success = setSleepDisabled(false)
        if success {
            automaticTurnOffRetryScheduled = false
        } else {
            isSleepDisabled = true
            updateUI()
            if !automaticTurnOffRetryScheduled {
                automaticTurnOffRetryScheduled = true
                let retryTimer = Timer(timeInterval: 300.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        guard let self = self else { return }
                        let retrySuccess = self.setSleepDisabled(false)
                        if !retrySuccess {
                            self.isSleepDisabled = true
                            self.updateUI()
                            if !self.automaticTurnOffAlertShown {
                                self.automaticTurnOffAlertShown = true
                                let alert = NSAlert()
                                alert.messageText = "Gagal Mematikan Mode Sleepless"
                                alert.informativeText = "Otomatisasi gagal mematikan pencegahan tidur. Silakan jalankan di Terminal:\nsudo pmset -a disablesleep 0"
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }
                        }
                    }
                }
                RunLoop.main.add(retryTimer, forMode: .common)
            }
        }
    }

    @objc func turnOffAction() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        setSleepDisabledManual(false)
    }

    @objc func enableForeverAction() {
        activateManual(duration: nil)
    }

    @objc func enableOneHourAction() {
        activateManual(duration: 3600)
    }

    @objc func enableThreeHoursAction() {
        activateManual(duration: 10800)
    }

    @objc func quit() {
        if isSleepDisabled {
            let success = setSleepDisabledManual(false)
            if !success {
                let alert = NSAlert()
                alert.messageText = "Gagal Mematikan Mode Sleepless"
                alert.informativeText = "Gagal mematikan pencegahan tidur sebelum keluar. Silakan jalankan di Terminal:\nsudo pmset -a disablesleep 0"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
