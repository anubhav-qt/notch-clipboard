# Redesign and categories plan (agreed 2026-11-17)

## Why
The first design copied the local Jello app too closely. The new look follows
mockup 3 ("Coral") from the review session, recoloured.

## Look
- Pure black panel, same notch reveal animation.
- Default accent stays the current lavender purple (191, 165, 255).
- Drop the dotted Doto heading look; use a calmer rounded system font.
- Rows: flat dark cards (#141414-ish), no Jello-style dot rule.
- Rows have no icon on the left; images still show their thumbnail.
- Under the title, one outlined squircle chip (no fill) with the category.
  No "Text" or "from App" chips (user decision, 2026-11-17).

## Title row (top)
- Left: the four filters All, Text, Images, Saved as one squircle toggle.
  Selected segment = accent text with an accent squircle outline, no fill.
- Right, in order: colour wheel button, trash, power.
- No Organize button: every clip is always sorted (user decision, 2026-11-17).
- Search moves to its own full-width row under the title row.

## Colour wheel button
- Sits just left of the trash button.
- Opens a row with 7 preset swatches, a hue bar and a reset button.
- The chosen colour tints every accent: tabs, bookmarks, icons, borders.
- Persist the choice across launches (UserDefaults is enough).
- Needs a "reset to default purple" option.

## Automatic categories (on-device Apple Intelligence)
- Uses Apple's Foundation Models framework (SystemLanguageModel, on device).
- Checked on this Mac (macOS 27.0.1): model is available, about 1.4 s per answer.
- App still targets macOS 14: gate with `if #available(macOS 26, *)` and the
  model's `availability`; hide the category bar when it is not available.
- Runs on its own in the background, newest clip first, one at a time.
  Nothing leaves the Mac. A refused or failed answer falls back to Reference.
- Hard cap: exactly these 4 fixed categories, never more, never invented ones.
  Use guided generation (a @Generable enum) so the model can only answer one of the 4.

### The 4 categories
Chosen by purpose ("where would I look for this later?"), one axis only, so
items do not fit two buckets as often as with mixed axes like "Code" vs "Work".

| Category  | Goes here |
|-----------|-----------|
| Work      | Job or study: code, terminal commands, errors, work docs, emails, tickets, meeting notes |
| Personal  | Own life: messages to friends or family, addresses, phone numbers, plans, shopping, money, health |
| Creative  | Making things: drafts, ideas, quotes, writing, design, colours, images and screenshots |
| Reference | Kept to look up later: links, facts, definitions, how-tos, numbers with no clear owner |

Tie-break order when two fit: Work, then Personal, then Creative, then Reference
(Reference is the catch-all). The on-device model reads text only, so images
and screenshots default to Creative.

## Bottom bar
- Like mockup 1's bottom tabs, but it holds the 4 categories: Work, Personal,
  Creative, Reference.
- Text only, no icons (user decision, 2026-11-17).
- Shows whenever the model is available. Tapping a category shows only that category
  (combined with the top filter and search). Tapping it again clears it.

## Decided defaults (no Organize button)
1. New clips are sorted automatically as soon as they are copied.
2. Saved items keep their category across launches (stored in saved.plist).
3. No progress UI: an unsorted clip just shows in "All" until it is sorted.
4. Checked on 14 sample clips with the real model: 14 right, about 0.3 s each.

## Still pending
- Unbounded session memory (many large screenshots) is a decision for the user.
- Project is not a git repository yet; commits need `git init` first (ask).
