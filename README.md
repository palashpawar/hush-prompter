# Hush

A notch teleprompter for macOS, in the spirit of [Moody](https://moodyteleprompter.com/). Your script sits
in a black extension of the MacBook notch, right under the camera, so you read while keeping eye contact.

- **Notch or floating**: dock it under the camera, or drag/resize it anywhere (works on external displays too)
- **Invisible to screen sharing**: the prompter is excluded from screen shares, recordings and screenshots
- **Cues**: start a line with `#` to make a section, then jump between them
- **Voice activated**: scrolls only while you're talking (mic level gate, audio stays on device)
- **Pause on hover**, trackpad scrolling, click to play/pause, speed, text size, color, mirror mode

## Shortcuts (global)

| Keys | Action |
| --- | --- |
| ⌃⌥Space | Play / pause |
| ⌃⌥↑ / ↓ | Faster / slower |
| ⌃⌥← / → | Previous / next cue |
| ⌃⌥R | Back to top |
| ⌃⌥H | Show / hide prompter |

## Build

Needs only the Xcode Command Line Tools.

```bash
./build.sh && open build/Hush.app
```

`SDK=/path/to/MacOSX.sdk ./build.sh` overrides the SDK if your compiler and default SDK don't match.
