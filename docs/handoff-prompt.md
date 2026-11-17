Notch Clipboard 1.3 at:
/Users/anubhav/Documents/Codex/2026-11-03/chang/outputs/notch-clipboard

Read first: CLAUDE.md, docs/plan-1.3.md, ~/.claude/CLAUDE.md.

## State (2026-11-17)
- 1.3.0 (build 10) is built and installed; ./test.sh, ./test-ui-inputs.sh and ./test-live.sh pass.
- Planted mistakes were caught (reorder default, join spacing, mixing, stale answers, retry version,
  remove debounce). The field's own 20-character cap is backed up by the draft's cap, so removing it
  alone changes nothing visible.

## Left to do
1. Check in the real app by eye: Select mode keeps the panel open, menus, editor under the notch.
2. Image sorting on real screenshots: LinkedIn shots split between Work and Reference; ask the user.
3. Optional LiveTests: Select mode stays open on pointer exit and Escape ends it.
4. Git and v1 release done. Open user decision: unbounded session memory for big screenshots.
