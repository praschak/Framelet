# Framelet

Framelet is a small macOS menu bar app focused on recording the current app's window. It's designed for long, low-frame-rate recordings where the screen content and clear audio matter more than smooth video.

Framelet is a fork of [Azayaka](https://github.com/Mnpn/Azayaka) by [Martin Persson](https://github.com/Mnpn) and contributors. Thank you for creating and sharing the original project — its ScreenCaptureKit recorder is the foundation for Framelet.

## What it does

- Record a window from the focused app using a configurable global shortcut or the menu bar.
- Capture system audio and, optionally, the microphone as separate AAC tracks.
- Choose 1, 5, 15, or 30 fps and H.264 or H.265, with MP4 or MOV output.
- Optionally merge the audio tracks after recording. The video is copied without re-encoding; the original is replaced only after the mixed file passes basic checks. FFmpeg is required for this option.
- Write movie fragments periodically to improve the chances of recovering a recording after an app crash.
- Check the output volume before and during a recording and stop when less than 1 GB is free. Merging is skipped if there isn't room for a temporary copy and the 1 GB reserve.
- Include the captured window title (`%n`) and start time (`%t`) in the output filename.
- Optionally extract on-screen text into a timestamped Markdown file at 30-second, 1-, 2-, or 5-minute intervals.
- Optionally transcribe the finished recording using the MacWhisper CLI with automatic language detection.
- Optionally start at login and stay in the menu bar.

## Requirements

- macOS 15 or later.
- Screen & System Audio Recording permission, and Microphone permission if recording a microphone.
- FFmpeg installed separately for optional audio merging. Framelet looks on `PATH`, `/opt/homebrew/bin`, `/usr/local/bin`, and `/opt/local/bin`.
- MacWhisper with its `mw` command-line tool installed for optional transcription. Markdown export requires MacWhisper Pro and a model supporting automatic language detection. MacWhisper uses its selected transcription provider; cloud providers may send audio to that service.

## Build with Command Line Tools

Install Apple's Command Line Tools and a compatible Swift toolchain. An internet connection is needed on the first build to fetch the pinned keyboard shortcut dependency. The build script uses the macOS 26.5 Command Line Tools SDK if available, or the active SDK otherwise; set `FRAMELET_SDK_PATH` to override it.

Build for the current Mac's architecture:

```bash
./build-command-line.sh
open build/Framelet.app
```

To build for both Apple silicon and Intel, use a toolchain that includes libraries for both architectures:

```bash
FRAMELET_UNIVERSAL=1 ./build-command-line.sh
file build/Framelet.app/Contents/MacOS/Framelet
codesign --verify --deep --strict --verbose=2 build/Framelet.app
```

The script requires a fresh output path: move an existing `build/Framelet.app` aside before rebuilding. Builds are ad-hoc signed and not notarized; permissions may need to be granted again after a rebuild. Test recording, permissions, shortcuts, and both architectures before distributing.

To enable launch at login, first move the built app to a stable location such as Applications, then enable the setting in Framelet. macOS may require approval in System Settings.

OCR and transcription are optional postprocessing steps. They write ` - ocr.md` and ` - transcript.md` files beside the video. Enable audio merging when you need both microphone and system audio in the track sent for transcription. Existing Markdown files are not overwritten.

## Recording and recovery

Focus the app to record, then use the configured shortcut. Press the same shortcut to stop. When merging is disabled, the microphone and system audio are separate tracks; some players play only one of them by default.

Fragmented output and the free-space guard reduce the risk of losing an interrupted recording, but neither guarantees recovery. Disk use can change between checks, and sleep or a system crash may interrupt finalization. Framelet attempts to stop when the Mac sleeps. Stop a recording before closing the lid when the recording matters.

A force-quit test has been reported to recover an interrupted recording. Sleep/wake behavior, storage exhaustion, long recordings, and audio/video synchronization still need broader testing. See [STABILITY-NOTES.md](STABILITY-NOTES.md) for known limitations.

## Credits

Thanks again to Martin Persson and everyone who contributed to [Azayaka](https://github.com/Mnpn/Azayaka). Framelet also uses [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus and contributors. FFmpeg is an optional external tool and is not bundled.
