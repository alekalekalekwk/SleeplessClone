import SwiftUI
import Carbon.HIToolbox

struct PopoverView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var controller = SleepController.shared
    @ObservedObject var popoverState = PopoverState.shared
    
    // Duration options: label and minutes (nil = infinite)
    private let durationOptions: [(String, Int?)] = [
        ("30m", 30),
        ("1h", 60),
        ("2h", 120),
        ("4h", 240),
        ("∞", nil)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Mode selector
            Picker(selection: $settings.mode, label: Text("")) {
                Text("Duration").tag(0)
                Text("Battery").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: .infinity)
            
            if settings.mode == 0 {
                // Duration chips
                HStack(spacing: 8) {
                    ForEach(durationOptions, id: \ .0) { opt in
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                settings.durationMinutes = opt.1
                            }
                        }) {
                            Text(opt.0)
                                .font(.system(size: 13))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(settings.durationMinutes == opt.1 ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundColor(settings.durationMinutes == opt.1 ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
            } else {
                // Battery slider
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: Binding(
                        get: { Double(settings.stopAtBatteryPercent) },
                        set: { settings.stopAtBatteryPercent = Int($0) }
                    ), in: 10...100, step: 5)
                    Text("Until battery hits \(settings.stopAtBatteryPercent)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Primary button
            Button(action: primaryAction) {
                Text(controller.isSleepDisabled ? "Stop" : "Start")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .cornerRadius(8)
            
            // When active, show status line
            if controller.isSleepDisabled {
                VStack(spacing: 2) {
                    if let end = controller.endDate {
                        Text(end, style: .timer)
                            .monospacedDigit()
                    } else {
                        Text("Until you stop")
                            .font(.subheadline)
                    }
                    Text("Stops at \(settings.stopAtBatteryPercent)% battery")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Shortcut row
            HStack {
                Text("Shortcut")
                Spacer()
                if popoverState.isRecording {
                    Text("Press keys…")
                } else {
                    Text(settings.hotkeyDisplayString)
                }
                Button(action: { popoverState.isRecording = true }) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            
            if let err = popoverState.hotkeyError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            Button("Quit") {
                SleepController.shared.quit()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 260)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            KeyRecorder(isRecording: $popoverState.isRecording) { keyCode, modifiers in
                let ok = HotKeyManager.shared.register(keyCode: keyCode, carbonModifiers: modifiers)
                if ok {
                    settings.hotkeyKeyCode = keyCode
                    settings.hotkeyModifiers = modifiers
                    popoverState.hotkeyError = nil
                } else {
                    popoverState.hotkeyError = "Shortcut already in use"
                }
                popoverState.isRecording = false
            }
        )
    }
    
    private func primaryAction() {
        if controller.isSleepDisabled {
            _ = controller.deactivate()
        } else {
            _ = controller.activate(minutes: settings.durationMinutes)
        }
    }
    
    private func formatRemaining(_ secs: TimeInterval) -> String {
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        let s = Int(secs) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
}

// Key recorder view
struct KeyRecorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onRecord: (UInt32, UInt32) -> Void
    
    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.isRecording = $isRecording
        view.onRecord = onRecord
        return view
    }
    
    func updateNSView(_ nsView: RecorderView, context: Context) {}
    
    class RecorderView: NSView {
        var isRecording: Binding<Bool>!
        var onRecord: ((UInt32, UInt32) -> Void)!
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            guard isRecording.wrappedValue else {
                super.keyDown(with: event)
                return
            }
            if event.keyCode == 53 { // Escape
                isRecording.wrappedValue = false
                return
            }
            var carbonMods: UInt32 = 0
            let flags = event.modifierFlags
            if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
            if flags.contains(.option) { carbonMods |= UInt32(optionKey) }
            if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
            if flags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
            onRecord(UInt32(event.keyCode), carbonMods)
        }
    }
}
