# Notch Clipboard

Clipboard history that lives in your MacBook's notch.
Move the pointer to the notch and your recent copies drop down from it.

https://github.com/user-attachments/assets/f0c956b4-1e33-4199-9428-56abc49ae804

## Features

- **Hover the notch** to open the history. Move away and it folds back in.
- **Click a clip** to put it back on the clipboard, then press ⌘V.
- **Text, links, images and files** are all kept. Images show a thumbnail.
- **Screenshots go to the clipboard.** ⌘⇧3 and ⌘⇧4 copy instead of saving a file.
- **Save clips** with the bookmark. Saved clips stay after a restart.
- **Filter** by All, Text, Images or Saved, and **search** as you type.
- **Automatic categories.** Apple Intelligence sorts each clip on your Mac.
  The tabs beside search show them: Work, Personal, Creative and Reference to start.
- **Your own categories.** Rename, add, remove and drag to reorder, 1 to 10 of them.
- **Image titles.** On macOS 27 each image gets a short title and a category too.
- **Select mode** picks several clips. Text is pasted as one, joined with a space.
  Images are copied as separate items. Text and images can't be mixed.
- **Your accent colour**, from presets or any hue.
- **Reorder history** (off by default) moves a clip to the top when you copy it again.

## Requirements

- A Mac with a notch, on macOS 14 or later. Macs without a notch can open the
  panel from the menu bar icon.
- Categories need Apple Intelligence (macOS 26 or later). Without it the tabs
  are hidden and everything else works.
- Image titles and image sorting need macOS 27.

## Install

### From the release

Download it from the [v1 release](https://github.com/anubhav-qt/notch-clipboard/releases/tag/v1).
That page has step-by-step install instructions for everyone.
The app is not notarized, so the first open needs Open Anyway in System Settings > Privacy & Security.

The release app does not change your screenshot shortcuts or start at login.
Build from source for those.

### From source

You need Xcode (its Swift compiler). Then:

```bash
git clone https://github.com/anubhav-qt/notch-clipboard.git
```

```bash
cd notch-clipboard && ./install.sh
```

`install.sh` builds the app, installs it to `~/Applications`, sets ⌘⇧3 and ⌘⇧4
to copy to the clipboard (Control-⌘⇧3/4 still save files) and starts it at login.

## Privacy

- Nothing leaves your Mac. Sorting uses Apple's on-device model.
- History lives only in memory and is gone when you quit.
- Saved clips are stored in `~/Library/Application Support/Notch Clipboard/saved.plist`,
  readable only by you. They are not encrypted.
- Clips that password managers mark as concealed or transient are never kept.

## Uninstall

```bash
./uninstall.sh
```

This removes the app and the login item and puts the four screenshot shortcuts back.
Saved clips are kept.

## Build and test

| Command | What it does |
| --- | --- |
| `./build.sh` | Builds `build/Notch Clipboard.app` |
| `./test.sh` | Unit tests, on a private clipboard |
| `./test-ui-inputs.sh` | Clicks and types into a test copy of the panel |
| `./test-live.sh` | Drives the installed app and moves the real pointer |

More scripts and the full notes are in [README.txt](README.txt).
The demo video is made with Remotion in [`demo/`](demo).

## License

MIT. See [LICENSE](LICENSE).
