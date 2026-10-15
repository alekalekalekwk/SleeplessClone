import AppKit
import Foundation
import IOKit.ps

@MainActor
final class SleepController: ObservableObject {
    static let shared = SleepController()

    @Published var isSleepDisabled: Bool = false
    @Published var endDate: Date? = nil

    var sleepTimer: Timer?
    var batteryTimer: Timer?
    var automaticTurnOffRetryScheduled: Bool = false
    var automaticTurnOffAlertShown: Bool = false
    var onStateChange: (() -> Void)?

    private init() {}

    func start() {
        isSleepDisabled = readSleepDisabledState()
        onStateChange?()

        let timer = Timer(timeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkBatterySafety()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer
    }

    func applicationWillTerminate() {
        if isSleepDisabled {
            setSleepDisabled(false)
        }
    }

    func readSleepDisabledState() -> Bool {
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
        let cutoff = Settings.shared.stopAtBatteryPercent
        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] {
                let state = desc[kIOPSPowerSourceStateKey] as? String
                let isAC = (state == kIOPSACPowerValue)
                if !isAC,
                   let current = desc[kIOPSCurrentCapacityKey] as? Int,
                   let max = desc[kIOPSMaxCapacityKey] as? Int,
                   max > 0 {
                    let percent = Double(current) / Double(max) * 100.0
                    if percent <= Double(cutoff) {
                        automaticTurnOff()
                        break
                    }
                }
            }
        }
    }

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
            onStateChange?()
            return true
        }
        if setSleepDisabledUser(on) {
            isSleepDisabled = on
            onStateChange?()
            return true
        }
        return false
    }

    @discardableResult
    func setSleepDisabled(_ on: Bool) -> Bool {
        let result = trySudoSetSleep(on)
        if result {
            isSleepDisabled = on
            onStateChange?()
            return true
        }
        return false
    }

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

    @discardableResult
    func activate(minutes: Int?) -> Bool {
        automaticTurnOffRetryScheduled = false
        automaticTurnOffAlertShown = false
        sleepTimer?.invalidate()
        sleepTimer = nil

        let success = setSleepDisabledManual(true)
        if success {
            if let minutes = minutes {
                endDate = Date().addingTimeInterval(Double(minutes * 60))
                let timer = Timer(timeInterval: Double(minutes * 60), repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.automaticTurnOff()
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                sleepTimer = timer
            } else {
                endDate = nil
            }
            return true
        } else {
            endDate = nil
            return false
        }
    }

    @discardableResult
    func deactivate() -> Bool {
        sleepTimer?.invalidate()
        sleepTimer = nil
        endDate = nil
        let success = setSleepDisabledManual(false)
        return success
    }

    func automaticTurnOff() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        endDate = nil

        let success = setSleepDisabled(false)
        if success {
            automaticTurnOffRetryScheduled = false
        } else {
            isSleepDisabled = true
            onStateChange?()
            if !automaticTurnOffRetryScheduled {
                automaticTurnOffRetryScheduled = true
                let retryTimer = Timer(timeInterval: 300.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        guard let self = self else { return }
                        let retrySuccess = self.setSleepDisabled(false)
                        if !retrySuccess {
                            self.isSleepDisabled = true
                            self.onStateChange?()
                            if !self.automaticTurnOffAlertShown {
                                self.automaticTurnOffAlertShown = true
                                let alert = NSAlert()
                                alert.messageText = "Failed to Disable Sleep Prevention"
                                alert.informativeText = "Automatic turn-off failed. Please run in Terminal:\nsudo pmset -a disablesleep 0"
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

    func quit() {
        if isSleepDisabled {
            let success = setSleepDisabledManual(false)
            if !success {
                let alert = NSAlert()
                alert.messageText = "Failed to Disable Sleep Prevention"
                alert.informativeText = "Failed to turn off sleep prevention before quitting. Please run in Terminal:\nsudo pmset -a disablesleep 0"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
        NSApp.terminate(nil)
    }
}
