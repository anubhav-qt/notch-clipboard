# 1.3 plan: category row, editable categories, select mode, image titles (agreed 2026-11-17)

Built and installed as 1.3.0 (build 10) on 2026-11-17. All tests and the live test pass.
Agreed through chat mockups; the user approved each part below.

## Title row
- Unchanged from 1.2: All/Text/Images/Saved squircle toggle on the left.
- Right side, in order: colour picker, select icon (new), trash, settings (gear).
- Colour picker button: replace the rainbow `ColorWheelButton` with a plain
  one-colour palette icon in the same `IconButton` style as trash and power
  (SF Symbol `paintpalette`, user picked option 1). Grey when closed, accent
  colour while the picker row is open. The open picker row stays as it is.

## Second row: search plus category tabs (replaces the bottom category bar)
- The bottom category bar is removed.
- Category tabs sit on the right of the search row, style "underline tabs":
  text only, accent colour plus a short accent underline on the chosen one.
- Each tab is only as wide as its text plus a little padding left and right.
- Search fills all the remaining width on the left.
- Tabs shown: All, then the first 3 categories in the user's order, then
  "More" with a chevron. All is the default selection.
- All can be placed First (default) or Last among the visible tabs, never in More.
- Tapping All clears the category filter.

## More menu
- Lists every category after the first 3, in the user's order.
- A divider, then "Add/Edit categories" (pencil icon, accent colour) at the foot.

## Add/Edit categories sheet
- Opens over the panel like the Clear sheet.
- Top row: an uneditable "All" field with a two-segment squircle toggle
  "First" / "Last" (First is default). No "always first" text.
- A divider, then one row per category: 3x3 dot drag handle (9 dots in a square),
  editable name field, remove (x) button.
- A plain dashed line, with no text, after the 3rd category shows where More starts.
- "Add category" row (plus icon, accent) at the end.
- Footer: hint text "Hold and drag [dots icon] to reorder" (the real 9-dot icon inline, not words) on the left, "Done" on the right.
- Starts with Work, Personal, Creative, Reference.

### Category decisions (user answered 2026-11-17)
- Categories are data now (id plus name), saved in UserDefaults. The model gets
  the names through `DynamicGenerationSchema(anyOf:)` (checked: macOS 26 API,
  answered "Recipes" for a recipe), so it still cannot invent one.
- Rename keeps every clip in place (clips store the id, not the name).
- Any add or remove sorts every clip again in the background. Reorder does not.
- Limits: 1 to 10 categories, names 1 to 20 characters. An empty name or a
  repeated name (any case, spaces trimmed) shows a quiet red note; Done waits.
- macOS 26 images go to Creative, also after a rename. If Creative is removed,
  images get no chip and show under All only.
- The 4 starter categories keep their hint text for the model while their name
  is unchanged; any other name is sent as the name alone.
- A refused text clip goes to Reference; if Reference is removed it gets no chip.

## Select mode (multi-select copy)
- Select is an icon, not a text button: an `IconButton` in the same style as
  trash and power, showing stacked copies with a check (user picked option 4;
  SF Symbol `checkmark.rectangle.stack` is the closest, confirm the look in the
  real app), help text "Select items",
  right of the colour picker. It shows in the accent colour while select mode is on.
- In select mode each row shows a small empty squircle box on the right
  (in place of the bookmark). Tapping a row picks it and the box shows its
  number, which is the paste order. Picked rows get an accent outline.
- Text first: image rows dim. Tapping one shows a quiet note
  "Images can't be selected with text". Image first: text rows dim, note
  "Text can't be selected with images".
- Footer bar: "N selected" on the left, "Cancel" and "Done" on the right.
- Done puts everything on the clipboard at once: text clips joined with one
  space in pick order, as one string. Cmd+V then pastes them all.
- No preview text of what will be pasted (user said no).
- The store already ignores its own clipboard writes (`changeCount` sync in
  `ClipboardStore.choose`), so the joined copy is not re-captured.

## Image titles and image categories (agreed 2026-11-17)
- On macOS 27 the on-device model takes images: `SystemLanguageModel.default
  .capabilities.contains(.vision)` is true on this Mac, and a prompt can hold
  `Attachment(imageURL:)` or `Attachment(cgImage)` (both macOS 27 only).
- Probe results: a screenshot of this chat app gave "Code Review Audit", a blue
  wallpaper gave "Blue Tube Pattern", about 1.3 s each.
- Agreed: every copied image gets a short model-written title (2 to 5 words),
  shown as the row title instead of today's generic image title. Saved items
  keep their title across launches, like the category.
- Agreed: images are sorted into categories by the model looking at the
  picture, instead of always Creative.
- Gate with `#available(macOS 27, *)` and the `.vision` capability. On macOS 26,
  or if vision is missing or the model fails, keep today's behaviour (generic
  title, Creative).
- Image sorting by the model is not tried yet; check accuracy on real
  screenshots before shipping, like the 14-clip text check.
- Send a downscaled thumbnail, not the full image, to keep it fast and light.
- Search should match the new image titles.

### Select mode decisions (user answered 2026-11-17)
- Several images: Done writes them as separate pasteboard items in pick order.
- Done adds no new clip and changes nothing in history.
- While in Select mode the panel stays open on pointer exit and outside
  clicks. Only Done, Cancel or Escape end it.
- Files and PDF rows can't be picked (only text or images).

## Reorder history (user decision 2026-11-17)
- New setting "Reorder history", off by default.
- Off: a clip already in this session's history keeps its place (and age) when
  it is copied again, from the panel or with Cmd+C in another app. Only new
  clips go on top. Saved order never changes.
- On: today's behaviour, a re-copied clip moves to the top.
- Never adds a joined clip, in either mode.

## Settings menu (replaces the power button)
- The power icon becomes a gear (`gearshape`) in the same IconButton style.
- It opens a small dropdown: a "Reorder history" toggle switch, a divider,
  then "Quit Clipboard".
