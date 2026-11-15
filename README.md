# XBright

A tiny menu bar app that changes the real backlight brightness of external monitors on Apple Silicon Macs — made for the Mac mini, which has no brightness control of its own.

It talks DDC/CI to the monitor over the display cable, so it does the same thing as the buttons on the monitor. No overlay, no gamma tricks.

## Features

- One slider per external monitor in the menu bar
- Brightness keys (F1/F2) adjust the monitor under the mouse pointer, 5% per press
- Command line: `XBright get` and `XBright set <0-100> [display-index]`
- 440 lines of Swift, no dependencies

## Requirements

- Apple Silicon Mac, macOS 14 or later
- A monitor that supports DDC/CI (most Dell, LG, BenQ, ASUS… monitors do; check that DDC/CI is enabled in the monitor's own menu)
- USB-C, DisplayPort or HDMI. The built-in HDMI port of some Macs (M1, base M2) does not pass DDC

Tested on a Mac mini M2 Pro with a Dell U2719D and a generic 1080p monitor.

## Install

Download `XBright.zip` from [Releases](../../releases), unzip it and move `XBright.app` to `/Applications`.

The build is ad-hoc signed, not notarized, so macOS blocks it on first launch. Clear the quarantine flag once:

```sh
xattr -dr com.apple.quarantine /Applications/XBright.app
```

Or build it yourself:

```sh
git clone https://github.com/devhontran/xbright.git
cd xbright
./build.sh
open build/XBright.app
```

## Brightness keys

Click **Brightness keys F1/F2** in the menu and grant Accessibility access when macOS asks. The slider and the command line work without it.

Because the app is ad-hoc signed, macOS treats every new build as a different app and asks for Accessibility access again after an update.

## Command line

```sh
/Applications/XBright.app/Contents/MacOS/XBright get
/Applications/XBright.app/Contents/MacOS/XBright set 60      # all monitors
/Applications/XBright.app/Contents/MacOS/XBright set 60 1    # monitor 1 only
```

## Limits

- No software dimming fallback for monitors without DDC/CI
- No on-screen indicator when a brightness key is pressed
- Apple displays (Studio Display, Pro Display XDR) are not handled; macOS already controls those
- Intel Macs are not supported

## Support

XBright is free. If it saves you a reach for the monitor buttons, you can [buy me a coffee](https://buymeacoffee.com/devhontran).

## License

MIT
