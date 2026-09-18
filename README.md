# FnLangSwitch

FnLangSwitch is a small macOS app that uses the **Fn/Globe** key to switch
between enabled keyboard input sources without opening the standard macOS
picker.

<img src="screenshot.png" align="left" width="400">

The app runs without a Dock icon. A globe icon in the menu bar opens settings
and provides a way to quit the app.

<br clear="left">

## Requirements

- macOS 13 or later
- At least two enabled keyboard input sources for short-press switching

## Usage

1. In **System Settings > Keyboard**, set **Press globe key to** to
   **Do Nothing**. This prevents macOS from opening its own input-source picker.
2. Launch the app.
3. Press **Fn** briefly to cycle through all enabled keyboard input sources.
4. Hold **Fn** for more than 400 ms to open a menu with all enabled input
   sources.

The settings window includes **Launch at login**. If **Switch on Fn release**
is disabled, a short press switches immediately on Fn-down; if it is enabled,
the switch happens on release and a long press opens the input-source menu.

## How it works

- Monitors the Fn key via
  `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`.
- Switches input sources using the Carbon `TISSelectInputSource` API.
- Uses the HID key-down counter to avoid treating Fn+key combinations as plain
  Fn taps when release mode is enabled.
- Uses AppKit for the settings window so the package can build with the
  standalone Command Line Tools package without a SwiftUI macro plugin.

## Build

```sh
./build-app.sh
```

The script creates `.build/FnLangSwitch.app` and ad-hoc signs it for local use.
