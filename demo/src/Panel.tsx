// The clipboard panel, drawn from the same numbers as the SwiftUI views in components/.
import React from "react";
import { Easing } from "remotion";
import {
  CHEVRON_W, contains, DROPDOWN_W, dropdownHeight, dropdownOrigin, dropdownRows, EDITOR_ROW_GAP, EDITOR_ROW_H,
  editorAddRect, editorDoneRect, editorFieldRect, editorFrame, editorHandleRect, editorRowY, filterRects, FILTERS,
  hueBarRect, iconRect, IconName, listBottom, listTop, NOTCH_H, NOTCH_W, PAD, PANEL_H, PANEL_W, PICKER_H, PICKER_Y,
  pickBoxRect, bookmarkRect, Point, Rect, resetRect, RIGHT, searchRect, searchTop, SELECT_BAR_Y, selectButtonRect,
  segmentRects, swatchRect, tabRects, TOP,
} from "./layout";
import { Category, Clip, clipTitle, rowRects, State, tabsFor, visibleClips } from "./script";
import { Symbol } from "./Symbol";
import { accents, hueColor, labelWidths, presetOrder, rgba, RGB, rounded, theme } from "./theme";
import { Thumbnail } from "./Thumbnails";

const CARET = "rgb(52, 120, 246)";
const SELECTION = "rgba(52, 120, 246, 0.45)";
const PROBLEM = "rgb(255, 115, 115)";
const PLACEHOLDER = "rgba(255, 255, 255, 0.8)";

const ease = Easing.bezier(0.32, 0.72, 0, 1);

export function progress(t: number, start: number, seconds: number): number {
  const raw = (t - start) / seconds;
  if (raw <= 0) {
    return 0;
  }
  if (raw >= 1) {
    return 1;
  }
  return ease(raw);
}

function box(rect: Rect): React.CSSProperties {
  return { position: "absolute", left: rect.x, top: rect.y, width: rect.w, height: rect.h };
}

function text(size: number, weight = 400): React.CSSProperties {
  return { fontFamily: rounded, fontSize: size, fontWeight: weight, whiteSpace: "nowrap", lineHeight: 1.2 };
}

type Props = { state: State; t: number; pointer: Point | null; accent: RGB };

/** How open the panel is, from 0 (the notch) to 1. */
export function revealAmount(state: State, t: number): number {
  if (state.panelOpen) {
    return progress(t, state.panelAt, 0.32);
  }
  return 1 - progress(t, state.panelAt, 0.24);
}

export const Panel: React.FC<Props> = ({ state, t, pointer, accent }) => {
  const reveal = revealAmount(state, t);
  if (reveal <= 0) {
    return null;
  }
  const notchLeft = (PANEL_W - NOTCH_W) / 2;
  const left = notchLeft * (1 - reveal);
  const bottom = (PANEL_H - NOTCH_H) * (1 - reveal);
  const topRadius = 9 + 6 * reveal;
  const bottomRadius = 9 + 15 * reveal;
  const clip = `inset(0px ${left}px ${bottom}px ${left}px round ${topRadius}px ${topRadius}px ${bottomRadius}px ${bottomRadius}px)`;
  const blocked = state.editor !== null;
  let hover = pointer;
  if (blocked) {
    hover = null;
  }
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: PANEL_W, height: PANEL_H, background: theme.panel, clipPath: clip, overflow: "hidden" }}>
      <TitleRow state={state} hover={hover} accent={accent} />
      {state.picker ? <AccentPicker state={state} hover={hover} accent={accent} /> : null}
      <SearchRow state={state} t={t} hover={hover} accent={accent} />
      <ClipList state={state} t={t} hover={hover} accent={accent} />
      {state.selecting ? <SelectBar state={state} t={t} hover={hover} accent={accent} /> : null}
      <Menus state={state} t={t} hover={hover} accent={accent} />
      <EditorSheet state={state} t={t} pointer={pointer} accent={accent} />
    </div>
  );
};

type PartProps = { state: State; t?: number; hover: Point | null; accent: RGB };

// Title row

const Toggle: React.FC<{ titles: readonly string[]; chosen: string; x: number; y: number; hover: Point | null; accent: RGB }> = ({
  titles,
  chosen,
  x,
  y,
  hover,
  accent,
}) => {
  const rects = segmentRects(titles, x, y);
  const last = rects[rects.length - 1];
  const outer: Rect = { x, y, w: last.x + last.w + 2 - x, h: 30 };
  return (
    <>
      <div style={{ ...box(outer), border: `1px solid ${theme.line}`, borderRadius: 10, boxSizing: "border-box" }} />
      {titles.map((title, index) => {
        const rect = rects[index];
        const selected = title === chosen;
        let color = theme.dimText;
        if (contains(rect, hover)) {
          color = theme.text;
        }
        if (selected) {
          color = rgba(accent);
        }
        let border = "transparent";
        if (selected) {
          border = rgba(accent, 0.7);
        }
        return (
          <div
            key={title}
            style={{
              ...box(rect),
              ...text(12, 500),
              color,
              border: `1px solid ${border}`,
              borderRadius: 8,
              boxSizing: "border-box",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            {title}
          </div>
        );
      })}
    </>
  );
};

const symbols: Record<IconName, "paintpalette" | "checkmark.rectangle.stack" | "trash" | "gearshape"> = {
  palette: "paintpalette",
  select: "checkmark.rectangle.stack",
  trash: "trash",
  gear: "gearshape",
};

const IconButton: React.FC<{ name: IconName; active: boolean; hover: Point | null; accent: RGB }> = ({ name, active, hover, accent }) => {
  const rect = iconRect(name);
  let color = theme.dimText;
  if (contains(rect, hover)) {
    color = theme.text;
  }
  if (active) {
    color = rgba(accent);
  }
  return (
    <div style={{ ...box(rect), display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Symbol name={symbols[name]} size={12} color={color} />
    </div>
  );
};

const TitleRow: React.FC<PartProps> = ({ state, hover, accent }) => {
  return (
    <>
      <Toggle titles={FILTERS} chosen={state.filter} x={PAD} y={TOP} hover={hover} accent={accent} />
      <IconButton name="palette" active={state.picker} hover={hover} accent={accent} />
      <IconButton name="select" active={state.selecting} hover={hover} accent={accent} />
      <IconButton name="trash" active={false} hover={hover} accent={accent} />
      <IconButton name="gear" active={state.menu === "settings"} hover={hover} accent={accent} />
    </>
  );
};

// Accent picker

const AccentPicker: React.FC<PartProps> = ({ hover, accent }) => {
  const row: Rect = { x: PAD, y: PICKER_Y, w: RIGHT - PAD, h: PICKER_H };
  const bar = hueBarRect();
  const stops = [0, 0.17, 0.33, 0.5, 0.67, 0.83, 1].map((hue) => rgba(hueColor(hue))).join(", ");
  const reset = resetRect();
  let resetColor = theme.dimText;
  if (contains(reset, hover)) {
    resetColor = theme.text;
  }
  return (
    <>
      <div style={{ ...box(row), background: theme.card, borderRadius: 8 }} />
      {presetOrder.map((name, index) => {
        const rect = swatchRect(index);
        const color = accents[name];
        const same = Math.round(color[0]) === Math.round(accent[0]) && Math.round(color[1]) === Math.round(accent[1]) && Math.round(color[2]) === Math.round(accent[2]);
        let ring = "transparent";
        if (contains(rect, hover)) {
          ring = theme.dimText;
        }
        if (same) {
          ring = "white";
        }
        return (
          <div key={name} style={{ ...box(rect), borderRadius: 10, border: `1.2px solid ${ring}`, boxSizing: "border-box", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 16, height: 16, borderRadius: 8, background: rgba(color) }} />
          </div>
        );
      })}
      <div style={{ position: "absolute", left: bar.x, top: bar.y + 7, width: bar.w, height: 10, borderRadius: 5, background: `linear-gradient(to right, ${stops})` }} />
      <div style={{ ...box(reset), display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Symbol name="arrow.counterclockwise" size={12} color={resetColor} />
      </div>
    </>
  );
};

// Search and category tabs

function caretVisible(t: number): boolean {
  return Math.floor(t * 1.9) % 2 === 0;
}

const SearchRow: React.FC<PartProps> = ({ state, t = 0, hover, accent }) => {
  const top = searchTop(state.picker);
  const tabs = tabsFor(state.categories);
  const field = searchRect(tabs, top);
  const rects = tabRects(tabs, top);
  const moreIds = state.categories.slice(3).map((item) => item.id);
  const moreChosen = state.categoryId !== null && moreIds.includes(state.categoryId);
  return (
    <>
      <div style={{ ...box(field), background: theme.card, borderRadius: 9, display: "flex", alignItems: "center", paddingLeft: 11, paddingRight: 11, boxSizing: "border-box", gap: 7 }}>
        <Symbol name="magnifyingglass" size={13} color={theme.faintText} />
        <div style={{ ...text(12.5), color: state.query === "" ? PLACEHOLDER : theme.text, position: "relative", flex: 1, display: "flex", alignItems: "center" }}>
          {state.searchFocus && caretVisible(t) ? <div style={{ width: 1.5, height: 15, background: CARET, marginLeft: state.query === "" ? -1 : 0, order: state.query === "" ? 0 : 2 }} /> : null}
          <span style={{ order: 1 }}>{state.query === "" ? "Search" : state.query}</span>
        </div>
        {state.query !== "" ? <Symbol name="xmark.circle.fill" size={13} color={theme.faintText} /> : null}
      </div>
      {tabs.map((tab, index) => {
        const rect = rects[index];
        let selected = false;
        if (tab.key === "all") {
          selected = state.categoryId === null;
        } else if (tab.key === "more") {
          selected = moreChosen;
        } else {
          selected = state.categoryId === tab.key;
        }
        let color = theme.dimText;
        if (contains(rect, hover) || (tab.key === "more" && state.menu === "more")) {
          color = theme.text;
        }
        if (selected) {
          color = rgba(accent);
        }
        const textWidth = Math.min(92, Math.ceil(labelWidths[tab.title] ?? 40) + 1);
        return (
          <div key={tab.key} style={{ ...box(rect), color, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", paddingTop: 5, boxSizing: "border-box" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 3, height: 15 }}>
              <div style={{ ...text(12, 500), width: textWidth, textAlign: "center", overflow: "hidden", textOverflow: "ellipsis" }}>{tab.title}</div>
              {tab.chevron ? <Symbol name="chevron.down" size={8} color={color} style={{ width: CHEVRON_W }} /> : null}
            </div>
            <div style={{ marginTop: 4, height: 1.5, alignSelf: "stretch", marginLeft: 5, marginRight: 5, background: selected ? rgba(accent) : "transparent" }} />
          </div>
        );
      })}
    </>
  );
};

// The list

const Chip: React.FC<{ label: string; color: string; opacity: number }> = ({ label, color, opacity }) => {
  return (
    <div style={{ ...text(10.5, 500), color, padding: "2.5px 7px", borderRadius: 6, boxShadow: `inset 0 0 0 1px ${color.replace(/[\d.]+\)$/, "0.45)")}`, opacity, lineHeight: "13px" }}>
      {label}
    </div>
  );
};

function categoryName(categories: Category[], id: string | null): string | null {
  if (id === null) {
    return null;
  }
  const found = categories.find((item) => item.id === id);
  if (!found) {
    return null;
  }
  return found.name;
}

function isDimmed(state: State, item: Clip): boolean {
  if (!state.selecting || state.picks.length === 0) {
    return false;
  }
  const first = state.clips.find((other) => other.id === state.picks[0]);
  if (!first) {
    return false;
  }
  const firstIsImage = first.kind === "Image";
  const itemIsImage = item.kind === "Image";
  return firstIsImage !== itemIsImage;
}

const Row: React.FC<{ item: Clip; rect: Rect; state: State; t: number; hover: Point | null; accent: RGB }> = ({ item, rect, state, t, hover, accent }) => {
  const hovered = contains(rect, hover);
  const pickIndex = state.picks.indexOf(item.id);
  const picked = pickIndex >= 0;
  let outline = "transparent";
  if (picked) {
    outline = rgba(accent, 0.8);
  }
  const name = categoryName(state.categories, item.cat);
  const chipIn = progress(t, item.catAt, 0.3);
  const title = clipTitle(item);
  const titleIn = progress(t, item.titleAt, 0.35);
  let fallbackTitle: string | null = null;
  if (item.kind === "Image" && titleIn < 1 && item.titleAt > 0) {
    fallbackTitle = "Copied image / screenshot";
  }
  return (
    <div style={{ ...box(rect), borderRadius: 9, background: hovered ? theme.cardHover : theme.card, boxShadow: `inset 0 0 0 1px ${outline}`, opacity: isDimmed(state, item) ? 0.35 : 1 }}>
      <div style={{ position: "absolute", left: 12, right: 46, top: 0, bottom: 0, display: "flex", alignItems: "center", gap: 12 }}>
        {item.thumb ? <Thumbnail kind={item.thumb} size={42} radius={7} /> : null}
        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 6 }}>
          <div style={{ position: "relative", height: 15 }}>
            {fallbackTitle ? <div style={{ ...text(12.5), color: theme.text, position: "absolute", opacity: 1 - titleIn }}>{fallbackTitle}</div> : null}
            <div style={{ ...text(12.5), color: theme.text, position: "absolute", left: 0, right: 0, overflow: "hidden", textOverflow: "ellipsis", opacity: fallbackTitle ? titleIn : 1 }}>{title}</div>
          </div>
          <div style={{ display: "flex", alignItems: "center", height: 18 }}>
            {name ? <Chip label={name} color={rgba(accent)} opacity={chipIn} /> : null}
            <div style={{ flex: 1 }} />
            <div style={{ ...text(10.5), color: theme.dimText }}>{item.age}</div>
          </div>
        </div>
      </div>
      {state.selecting ? <PickBox rect={pickBoxRect(rect)} number={picked ? pickIndex + 1 : null} t={t} pickAt={state.pickAt} accent={accent} offset={rect} /> : <Bookmark rect={bookmarkRect(rect)} offset={rect} saved={item.saved} savedAt={item.savedAt} t={t} hover={hover} accent={accent} />}
    </div>
  );
};

function inside(rect: Rect, offset: Rect): Rect {
  return { x: rect.x - offset.x, y: rect.y - offset.y, w: rect.w, h: rect.h };
}

const Bookmark: React.FC<{ rect: Rect; offset: Rect; saved: boolean; savedAt: number; t: number; hover: Point | null; accent: RGB }> = ({ rect, offset, saved, savedAt, t, hover, accent }) => {
  let color = theme.faintText;
  if (saved) {
    color = rgba(accent);
  }
  if (contains(rect, hover)) {
    color = rgba(accent, 0.6);
  }
  let scale = 1;
  if (saved) {
    const pop = progress(t, savedAt, 0.3);
    scale = 1 + 0.25 * Math.sin(pop * Math.PI);
  }
  return (
    <div style={{ ...box(inside(rect, offset)), display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Symbol name={saved ? "bookmark.fill" : "bookmark"} size={12} color={color} style={{ transform: `scale(${scale})` }} />
    </div>
  );
};

const PickBox: React.FC<{ rect: Rect; offset: Rect; number: number | null; t: number; pickAt: number; accent: RGB }> = ({ rect, offset, number, t, pickAt, accent }) => {
  let border = theme.faintText;
  if (number !== null) {
    border = rgba(accent);
  }
  return (
    <div style={{ ...box(inside(rect, offset)), borderRadius: 5, boxShadow: `inset 0 0 0 1.2px ${border}`, display: "flex", alignItems: "center", justifyContent: "center" }}>
      {number !== null ? <div style={{ ...text(10.5, 600), color: rgba(accent), opacity: progress(t, pickAt, 0.15) > 0 ? 1 : 1 }}>{number}</div> : null}
    </div>
  );
};

const ClipList: React.FC<PartProps> = ({ state, t = 0, hover, accent }) => {
  const items = visibleClips(state);
  const top = listTop(state.picker);
  const bottom = listBottom(state.selecting);
  const change = progress(t, state.listAt, 0.22);
  const opacity = 0.2 + 0.8 * change;
  const shift = 4 * (1 - change);
  if (items.length === 0) {
    let message = "No items yet";
    if (state.query !== "") {
      message = "No matching items";
    } else if (state.categoryId !== null) {
      message = `No ${categoryName(state.categories, state.categoryId)} items`;
    } else if (state.filter === "Saved") {
      message = "No saved items";
    }
    return <div style={{ position: "absolute", left: PAD, top, width: RIGHT - PAD, height: bottom - top, display: "flex", alignItems: "center", justifyContent: "center", ...text(14, 500), color: theme.dimText, opacity }}>{message}</div>;
  }
  const rects = rowRects(items, top);
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: PANEL_W, height: bottom, overflow: "hidden" }}>
      <div style={{ position: "absolute", inset: 0, opacity, transform: `translateY(${shift}px)` }}>
        {items.map((item, index) => (
          <Row key={item.id} item={item} rect={rects[index]} state={state} t={t} hover={hover} accent={accent} />
        ))}
      </div>
    </div>
  );
};

// Select bar

const PanelButton: React.FC<{ rect: Rect; title: string; primary: boolean; enabled: boolean; hover: Point | null; accent: RGB }> = ({ rect, title, primary, enabled, hover, accent }) => {
  const hovered = contains(rect, hover);
  let color = "rgba(255,255,255,0.75)";
  let fill = `rgba(255,255,255,${hovered ? 0.09 : 0.035})`;
  let border = "rgba(255,255,255,0.15)";
  if (primary) {
    color = rgba(accent);
    fill = rgba(accent, hovered ? 0.22 : 0.12);
    border = rgba(accent, 0.4);
  }
  return (
    <div style={{ ...box(rect), ...text(12.5, 500), color, background: fill, boxShadow: `inset 0 0 0 0.7px ${border}`, borderRadius: 6, display: "flex", alignItems: "center", justifyContent: "center", opacity: enabled ? 1 : 0.4 }}>
      {title}
    </div>
  );
};

const SelectBar: React.FC<PartProps> = ({ state, hover, accent }) => {
  const count = state.picks.length;
  return (
    <>
      <div style={{ position: "absolute", left: PAD, top: SELECT_BAR_Y, width: RIGHT - PAD, height: 1, background: theme.line }} />
      <div style={{ position: "absolute", left: PAD, top: SELECT_BAR_Y + 5, height: 38, display: "flex", flexDirection: "column", justifyContent: "center", gap: 2 }}>
        <div style={{ ...text(12, 500), color: theme.text }}>{count} selected</div>
        {state.note ? <div style={{ ...text(10.5), color: theme.dimText }}>{state.note}</div> : null}
      </div>
      <PanelButton rect={selectButtonRect("cancel")} title="Cancel" primary={false} enabled hover={hover} accent={accent} />
      <PanelButton rect={selectButtonRect("done")} title="Done" primary enabled={count > 0} hover={hover} accent={accent} />
    </>
  );
};

// Dropdowns

const MenuRow: React.FC<{ rect: Rect; hover: Point | null; children: React.ReactNode }> = ({ rect, hover, children }) => {
  return (
    <div style={{ ...box(rect), borderRadius: 6, background: contains(rect, hover) ? theme.cardHover : "transparent", display: "flex", alignItems: "center", paddingLeft: 10, paddingRight: 10, boxSizing: "border-box", gap: 8 }}>
      {children}
    </div>
  );
};

const Menus: React.FC<PartProps> = ({ state, t = 0, hover, accent }) => {
  if (state.menu === null) {
    return null;
  }
  const appear = progress(t, state.menuAt, 0.16);
  const top = searchTop(state.picker);
  let button: Rect;
  let kinds: ("row" | "switch" | "divider")[];
  const more = state.categories.slice(3);
  if (state.menu === "more") {
    const tabs = tabsFor(state.categories);
    button = tabRects(tabs, top)[tabs.length - 1];
    kinds = more.map(() => "row" as const);
    if (more.length > 0) {
      kinds.push("divider");
    }
    kinds.push("row");
  } else {
    button = iconRect("gear");
    kinds = ["switch", "divider", "row"];
  }
  const origin = dropdownOrigin(button);
  const rows = dropdownRows(origin, kinds);
  const card: Rect = { x: origin.x, y: origin.y, w: DROPDOWN_W, h: dropdownHeight(rows, origin) };
  const content: React.ReactNode[] = [];
  if (state.menu === "more") {
    more.forEach((category, index) => {
      content.push(
        <MenuRow key={category.id} rect={rows[index]} hover={hover}>
          <div style={{ ...text(12.5), color: theme.text }}>{category.name}</div>
        </MenuRow>,
      );
    });
    if (more.length > 0) {
      const divider = rows[more.length];
      content.push(<div key="divider" style={{ position: "absolute", left: origin.x, width: DROPDOWN_W, top: divider.y + 4, height: 1, background: theme.line }} />);
    }
    content.push(
      <MenuRow key="edit" rect={rows[rows.length - 1]} hover={hover}>
        <Symbol name="pencil" size={11} color={rgba(accent)} />
        <div style={{ ...text(12.5), color: rgba(accent) }}>Add/Edit categories</div>
      </MenuRow>,
    );
  } else {
    const knob = progress(t, state.reorderAt, 0.12);
    let on = 0;
    if (state.reorder) {
      on = knob;
    }
    const track = `rgba(${255 + (accent[0] - 255) * on}, ${255 + (accent[1] - 255) * on}, ${255 + (accent[2] - 255) * on}, ${0.18 + 0.82 * on})`;
    content.push(
      <MenuRow key="reorder" rect={rows[0]} hover={hover}>
        <div style={{ ...text(12.5), color: theme.text, flex: 1 }}>Reorder history</div>
        <div style={{ width: 28, height: 16, borderRadius: 8, background: track, position: "relative" }}>
          <div style={{ position: "absolute", top: 2, left: 2 + 12 * on, width: 12, height: 12, borderRadius: 6, background: "white" }} />
        </div>
      </MenuRow>,
    );
    content.push(<div key="divider" style={{ position: "absolute", left: origin.x, width: DROPDOWN_W, top: rows[1].y + 4, height: 1, background: theme.line }} />);
    content.push(
      <MenuRow key="quit" rect={rows[2]} hover={hover}>
        <div style={{ ...text(12.5), color: theme.text }}>Quit Clipboard</div>
      </MenuRow>,
    );
  }
  return (
    <div style={{ position: "absolute", inset: 0, opacity: appear, transform: `translateY(${-4 * (1 - appear)}px)` }}>
      <div style={{ ...box(card), background: theme.menu, borderRadius: 10, boxShadow: `inset 0 0 0 1px ${theme.line}` }} />
      {content}
    </div>
  );
};

// The category editor sheet

function editorRows(state: State, pointer: Point | null): Category[] {
  const editor = state.editor!;
  const rows = editor.rows.slice();
  if (editor.drag && pointer) {
    const pitch = EDITOR_ROW_H + EDITOR_ROW_GAP;
    const steps = Math.round((pointer.y - editor.drag.startY) / pitch);
    const target = Math.max(0, Math.min(rows.length - 1, editor.drag.start + steps));
    const moved = rows.splice(editor.drag.start, 1)[0];
    rows.splice(target, 0, moved);
  }
  return rows;
}

const EditorSheet: React.FC<{ state: State; t: number; pointer: Point | null; accent: RGB }> = ({ state, t, pointer, accent }) => {
  const opening = state.editor !== null;
  let amount = 1 - progress(t, state.editorAt, 0.18);
  if (opening) {
    amount = progress(t, state.editorAt, 0.2);
  }
  if (amount <= 0 || state.editor === null) {
    return null;
  }
  const editor = state.editor;
  const rows = editorRows(state, pointer);
  const frame = editorFrame(rows.length);
  const problem = rows.some((row) => row.name.trim() === "") ? "Names can't be empty" : null;
  const hover = pointer;
  const add = editorAddRect(frame, rows.length);
  const done = editorDoneRect(frame);
  const allBox: Rect = { x: frame.x + 16, y: frame.y + 16 + 2, w: 150, h: 26 };
  const toggleX = frame.x + frame.w - 16 - (2 + labelWidths.First + 22 + 2 + labelWidths.Last + 22 + 2);
  const dashedY = editorRowY(frame, 3) - EDITOR_ROW_GAP / 2 - 0.5;
  return (
    <div style={{ position: "absolute", inset: 0, opacity: amount }}>
      <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,0.72)" }} />
      <div style={{ ...box(frame), background: theme.card, borderRadius: 12, boxShadow: `inset 0 0 0 0.7px ${rgba(accent, 0.3)}`, transform: `scale(${0.98 + 0.02 * amount})` }} />
      <div style={{ ...box(allBox), ...text(12.5), color: theme.dimText, background: "rgba(255,255,255,0.03)", borderRadius: 7, display: "flex", alignItems: "center", paddingLeft: 9, boxSizing: "border-box" }}>All</div>
      <Toggle titles={["First", "Last"]} chosen="First" x={toggleX} y={frame.y + 16} hover={hover} accent={accent} />
      <div style={{ position: "absolute", left: frame.x + 16, top: frame.y + 16 + 30 + 10, width: frame.w - 32, height: 1, background: theme.line }} />
      {rows.map((row, index) => {
        const field = editorFieldRect(frame, index);
        const handle = editorHandleRect(frame, index);
        const dragging = editor.drag !== null && editor.drag.id === row.id;
        const focused = editor.focus === row.id;
        const remove: Rect = { x: field.x + field.w + 8, y: field.y, w: 24, h: EDITOR_ROW_H };
        let handleColor = theme.faintText;
        if (dragging || contains(handle, hover)) {
          handleColor = theme.text;
        }
        let removeColor = theme.faintText;
        if (contains(remove, hover)) {
          removeColor = theme.text;
        }
        return (
          <React.Fragment key={row.id}>
            <div style={{ ...box(handle), display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Symbol name="circle.grid.3x3.fill" size={9} color={handleColor} />
            </div>
            <div style={{ ...box(field), background: "rgba(255,255,255,0.06)", borderRadius: 7, boxShadow: dragging ? `inset 0 0 0 1px ${rgba(accent, 0.7)}` : "none", display: "flex", alignItems: "center", paddingLeft: 9, boxSizing: "border-box", ...text(12.5), color: theme.text }}>
              <span style={{ background: focused && editor.allSelected ? SELECTION : "transparent", borderRadius: 2 }}>{row.name}</span>
              {focused && !editor.allSelected && caretVisible(t) ? <div style={{ width: 1.5, height: 15, background: CARET, marginLeft: 1 }} /> : null}
            </div>
            <div style={{ ...box(remove), display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Symbol name="xmark" size={10} color={removeColor} />
            </div>
          </React.Fragment>
        );
      })}
      {rows.length > 3 ? <div style={{ position: "absolute", left: frame.x + 16, width: frame.w - 32, top: dashedY, height: 0, borderTop: `1px dashed ${theme.faintText}` }} /> : null}
      <div style={{ ...box(add), display: "flex", alignItems: "center", gap: 7, color: rgba(accent), opacity: contains(add, hover) ? 1 : 0.85 }}>
        <Symbol name="plus" size={11} color={rgba(accent)} />
        <div style={{ ...text(12.5) }}>Add category</div>
      </div>
      <div style={{ position: "absolute", left: frame.x + 16, top: done.y, height: 28, display: "flex", alignItems: "center", gap: 4, ...text(11), color: problem ? PROBLEM : theme.faintText }}>
        {problem ?? (
          <>
            Hold and drag <Symbol name="circle.grid.3x3.fill" size={11} color={theme.faintText} /> to reorder
          </>
        )}
      </div>
      <PanelButton rect={done} title="Done" primary enabled={problem === null} hover={hover} accent={accent} />
    </div>
  );
};

export { PANEL_W as PANEL_WIDTH };
