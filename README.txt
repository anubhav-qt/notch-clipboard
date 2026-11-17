NOTCH CLIPBOARD

Installed as ~/Applications/Notch Clipboard.app. The app is written entirely
in Swift with SwiftUI, AppKit and Core Animation. No Rust or webview is needed.

USE
Move the pointer to the notch to expand clipboard history. The animation starts
immediately. Moving outside the expanded panel starts contraction immediately.
The panel stays centered on the physical notch, in normal and full-screen use.
Only the hardware notch bounds open it; there is no extra hit area on either
side or underneath. Displays without a notch use the menu bar Open action.
Click any item to put it back on the system clipboard. It keeps its place in the
list unless Reorder history is on (gear menu, off by default), which moves it to
the front. Then press Command-V in your app. Escape dismisses the panel.

Command-Shift-3 copies a full-screen screenshot to the clipboard.
Command-Shift-4 copies a selected region to the clipboard.
Control-Command-Shift-3/4 retain the file-saving actions.

Clipboard capture stays on while the app is running. The title row holds the
All / Text / Images / Saved toggle, then four grey icons: palette (accent
colour), Select, Clear History and the gear. The gear menu holds the Reorder
history switch and Quit Clipboard.
Search shares its row with the category tabs and searches within the filter.
Return copies the first result. Images show a thumbnail; other rows have no icon.
Files retain their URLs.

SELECT MODE
The Select icon lets you pick several rows; each shows its pick number.
Text and links can be picked together, images only with images; a quiet note
says so. Done copies the text joined with one space, or the images as separate
items. Escape or Cancel ends Select mode; the panel stays open while selecting.

CATEGORIES
Every clip is sorted into one category by Apple's on-device model (Apple
Intelligence, macOS 26 or later). Nothing leaves the Mac. Sorting runs in the
background, one clip at a time, newest first; there is no button.
The categories start as Work, Personal, Creative and Reference. More > Add/Edit
categories renames, removes, adds (1 to 10, names up to 20 characters) and
reorders them by dragging the dots; All can sit first or last. Adding or
removing a category sorts everything again; renaming or moving does not.
The tabs beside search show All, the first three categories and More.
On macOS 27 the model also looks at each image, gives it a short title and
sorts it. On macOS 26 images go to Creative without asking the model.
A refused or failed answer goes to Reference (or no category if it was
removed); a busy model is retried after 30 s.
Saved items keep their category and title in saved.plist. Without Apple
Intelligence the tabs are hidden and nothing is sorted.

ACCENT COLOUR
The palette icon opens a row of preset swatches, a hue bar and a reset button.
The default is lavender purple (#BFA5FF). The choice is stored in the app's
defaults under "accentColor" and tints every accent in the panel.

Click an entry to copy it. Click its bookmark icon to save or unsave it without
changing the clipboard. Unsaved bookmarks remain grey outlines when a row is hovered. Hovering the
bookmark itself tints it in a dim accent; only saved bookmarks are filled.
Row highlighting tracks entry and exit immediately, even without keyboard focus.
Removing a saved item asks "Remove from Saved?" with Yes and No buttons.
"Don't ask again in this session" skips later removal prompts until the app quits.
Closing the panel, changing filters and clearing history do not reset it.

HISTORY AND STARTUP
All, Text and Images contain only the current app session. They start empty
on launch and retain captured entries until Clear History or Quit. Clear History
keeps saved items and the current system clipboard.

Bookmarked entries persist across sessions on this Mac in:
~/Library/Application Support/Notch Clipboard/saved.plist
The folder is owner-only (0700); saved files use permissions 0600.
Saved items are an unencrypted local binary property list. Nothing is uploaded.
The previous version's history.plist is left in place, but is no longer loaded
or written. Individual captures over 64 MiB are skipped.
Password-manager clipboard items explicitly marked concealed or transient
are excluded. Unmarked copied text is recorded normally.

The login LaunchAgent is:
~/Library/LaunchAgents/local.notchclipboard.app.plist
It launches once at login and respects Quit for the rest of that session.

BUILD AND TEST
./build.sh      Build the app with the installed Xcode Swift compiler.
./test.sh       Test using a separate, named clipboard; your clipboard is untouched.
./test-saved-removal.sh Test Yes/No removal, the session checkbox and reset
                        after a new app session, using a separate clipboard.
./test-presentation.sh Test exact notch boundaries, stale native-window recovery
                       and inactive-panel hover latency.
./test-ui-inputs.sh Click and type into a test copy of the panel: search, toggle,
                    bookmarks, tabs, More, the category editor, gear menu,
                    Select mode, palette and Clear History.
./test-live.sh  Drive the installed app: menu Open, outside clicks, pointer exit,
                the Clear sheet and Escape. Moves the pointer for about 15 s.
./test-spaces.sh Test the running app through repeated desktop/full-screen
                 transitions and minimize/restore. Opens temporary test windows.
./install.sh   Build, install, set the screenshot shortcuts and start at login.
./uninstall.sh Remove the app and restore only the four original screenshot
               shortcuts. Saved history is retained.

Build output: build/Notch Clipboard.app
Source: the *.swift files at the top level (logic) and components/ (SwiftUI
        views). sources.zsh lists them for the build and test scripts.

DESIGN
Black panel, flat #141414 cards, rounded system font and squircle corners.
One accent colour, chosen by the user. The earlier Jello-like look (dotted
Doto headings, Open Sans) was replaced in 1.2; the fonts are no longer bundled.
Opening lasts 140 ms and closing 110 ms, with no hover waiting period.

VERSION 1.3
Category tabs beside search, editable categories, Select mode, the gear menu
with Reorder history, and image titles and image sorting on macOS 27.

VERSION 1.2
New look, user accent colour, and automatic on-device categories.
After a dialog closes with the pointer outside, the panel now waits for the
pointer to visit again instead of closing at once.

VERSION 1.1.5
Clipboard polling and age refresh now use elapsed time rather than timer counts.
A visible panel reconciles native hover state with current pointer geometry, so
a missing entered/exited event cannot leave a row highlighted indefinitely.
User-interaction activity is scoped to the open panel and allows system sleep.
Recovery waits for WindowServer Space-animation movement to settle instead of
rebuilding a surface while it is still moving.

Local diagnostics record timer gaps, slow clipboard/thumbnail work, panel
transitions and hover corrections in the Application Support folder:
timing.jsonl and timing-previous.jsonl (up to 1 MiB each, permissions 0600).
They contain event timings and state flags, without copied text, image data,
entry identifiers or mouse paths. No screen recording is required. The precise
cause of an intermittent incident still needs its timing record; App Nap has
not been established as the cause of the original recording-dependent symptom.

VERSION 1.1.4
Entry ages show minutes for the first 20 minutes, then five-minute steps until
an hour, then whole hours. No seconds are displayed. Foreground focus changes
no longer dismiss a panel that is still being used under the pointer.

VERSION 1.1.3
The Saved confirmation is now drawn inside the clipboard panel with the same
dark surface, fonts and purple accent. It has no application icon or separate
modal window. Click the backdrop or press Escape to cancel. Clicking another
app cancels confirmation and closes the panel. Moving outside while deciding
keeps the confirmation visible. Unconfirmed checkbox changes are discarded.

VERSION 1.1.2
Removing from Saved now has a Yes/No confirmation with a session-only
"Don't ask again in this session" checkbox. The preference resets after Quit.
Escape cancels removal without dismissing the clipboard panel.

VERSION 1.1.1
The SwiftUI content is retained while each opening gets a new native panel,
so a long-lived window cannot carry old WindowServer/Space state indefinitely.
Exposure checks use WindowServer hit testing; an ordered, active-Space flag
alone no longer passes as visible. A hidden surface is rebuilt automatically.
Native activeAlways tracking makes row and bookmark hover independent of focus.
The trigger uses the hardware notch bounds without expanded margins.

VERSION 1.1
Always-on session history, persistent bookmarked items, four content filters,
a compact search field and direct clear/quit controls. The title is just
Clipboard; the footer, icon, counter, pause control and overflow menu are gone.

VERSION 1.0.1
The panel now explicitly joins other apps' full-screen Spaces and clears stale
presentation state when the active Space, foreground app or displays change.
A pending contraction from an old Space cannot hide a newly opened panel.
Visibility checks also recover if macOS removes a supposedly open panel from
the active Space. See space-regression-results.txt for the completed checks.
