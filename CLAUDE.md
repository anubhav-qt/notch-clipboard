# Notch Clipboard

macOS menu-bar app (Swift, SwiftUI, AppKit). Hovering the notch opens a clipboard
history panel. Built with plain `swiftc` (no Xcode project), targets macOS 14.

## Layout
- Top-level `*.swift`: logic. `NotchClipboard.swift` is the app delegate (hover,
  open/close, Spaces, status menu). `ClipboardStore` captures and saves clips,
  `ClipboardModel` feeds the views, `ClipCategorizer` talks to Apple's on-device
  model, `AccentColor` is the user's colour (any hex; `AccentShade` keeps hue,
  strength and brightness for the picker), `PanelSurface` rebuilds a lost window,
  `ImageFiles` writes image clips as PNGs to ~/Pictures/Notch Clipboard.
- `components/`: every SwiftUI view. Reuse these; new UI goes here too.
- `*Tests.swift`: one small executable per area, run by the scripts below.
- `sources.zsh`: shared source lists, plugin path and `-target` for all scripts.
- `docs/redesign-plan.md`: agreed 1.2 design (replaced in parts by 1.3).
- `docs/plan-1.3.md`: 1.3 spec and decisions, built and installed.
- `docs/handoff-prompt.md`: exact state of the 1.3 work and what is left.
- `demo/`: Remotion demo video, drawn in React from the components' numbers.
  `npm run setup` (fonts, symbols), `npm run render` writes `demo/out/`. Story in `src/script.ts`.
- 1.3 files: `CategoryList` (list, tabs, edit draft), `ClipSorting` (model sorting),
  `ClipSelection` (Select mode picks).

## Commands
- `./build.sh`, `./install.sh` (installs to ~/Applications and restarts it).
- `./test.sh` unit tests (`./test.sh ImageFilesTests` runs one); `./test-ui-inputs.sh` native clicks on a test panel
  (`palette` or `settings` as argument runs only those; run only what you changed);
  `./test-saved-removal.sh`, `./test-presentation.sh`; `./test-live.sh` drives the
  installed app and moves the real pointer; `./test-spaces.sh` opens windows.

## Rules
- Categories are user data (1 to 10, names up to 20), starting Work, Personal,
  Creative, Reference. The model answers through `DynamicGenerationSchema(anyOf:)`
  so it cannot invent one. No Organize button.
- FoundationModels is weak-linked; guard with `#available(macOS 26, *)`.
- Tests never touch the real clipboard (`NSPasteboard.withUniqueName()`), the
  real model (`categorizer: nil` or a fake) or real defaults (a UUID suite).
- Rows show no icons (image thumbnails only) and one category chip. Category
  tabs sit right of search, text only. Reorder history is off by default.
- Settings: Reorder history and Save images as files, both off by default. With image
  files on, an image clip pastes as its PNG file plus the picture; text is untouched.
- Accent picker: 8 presets (white last), hex box, shade square, hue bar. Any colour.
- Light on resources: the loop runs at 120 Hz only while the panel is open or the pointer is
  within 160 pt of a notch, else 10 Hz (`MonitorSchedule.interval`); the clipboard is checked
  twice a second. History has no size limit.
- UI tests type before any `screenImage`: screencapture takes keyboard focus away.
- Icon colour checks in UIInputTests read the screen (`screenImage`): offscreen
  `cacheDisplay` paints the palette symbol white under the panel clip.
- Git: main on github.com/anubhav-qt/notch-clipboard (public, MIT), tags v1 and v1.1 (app version in `build.sh`). `release/` (ignored) holds each zip and sha256, made with `ditto`.
