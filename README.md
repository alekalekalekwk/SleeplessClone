# SleeplessClone

macOS menu bar app that keeps your MacBook awake even when the lid is closed, by toggling `pmset -a disablesleep`.

## Build

Requires Swift 5.9+ and macOS 13+.

```
swift build
```

## Create .app bundle

```
chmod +x build_app.sh
./build_app.sh
```

This creates `SleeplessClone.app` in the project root.

## Run

```
open SleeplessClone.app
```

Or run the binary directly:

```
.build/debug/SleeplessClone
```

## Features

- Menu bar icon (moon) toggles sleep prevention
- "Aktifkan selamanya" / "Aktifkan 1 jam" / "Aktifkan 3 jam" duration options
- Timer auto-turns off when it expires
- Requests admin privileges via password prompt (NSAppleScript)
- On quit: restores normal sleep (`disablesleep 0`)
- On launch: reads `pmset -g` to sync current state
- Battery safety: if not on AC power and battery <= 20%, auto-turns off

## Sudoers Configuration (Passwordless Turn-Off)

To allow automatic timers, battery cutoff, and quit actions to turn off sleep prevention without requiring a GUI password dialog (especially when the laptop lid is closed), you can install the passwordless sudoers configuration:

```
./install_sudoers.sh
```

To remove it later:

```
./uninstall_sudoers.sh
```

### Security Trade-off
`install_sudoers.sh` grants your user permission to run ONLY `/usr/bin/pmset -a disablesleep 0` and `/usr/bin/pmset -a disablesleep 1` via `sudo` without a password. No wildcards are used. If not installed, manual toggle via the menu will still prompt for admin privileges with AppleScript, but background/automatic shutoffs (timer expiration, low battery, and quit) cannot trigger interactive password prompts and will alert or retry.

## Notes

- Hides from Dock (LSUIElement / setActivationPolicy(.accessory))
- Uses SF Symbols: `moon.zzz` (off) / `moon.zzz.fill` (on)
