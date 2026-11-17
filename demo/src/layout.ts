// Where everything sits. Panel numbers come from the SwiftUI code (paddings, frames, spacings),
// so the drawing and the pointer targets agree without measuring the page.
import { labelWidths } from "./theme";

export const FPS = 60;
export const VIDEO_W = 1920;
export const VIDEO_H = 1080;

// The desktop is drawn in macOS points, like a 14-inch MacBook Pro, then scaled by the camera.
export const DESKTOP_W = 1512;
export const DESKTOP_H = (DESKTOP_W * VIDEO_H) / VIDEO_W;
export const MENU_BAR_H = 32;

export const NOTCH_W = 185;
export const NOTCH_H = 32;

export const PANEL_W = 560;
export const PANEL_H = 440;
export const PANEL_X = (DESKTOP_W - PANEL_W) / 2;
export const PAD = 18;
/** max(17, notchHeight + 10) */
export const TOP = 42;
export const RIGHT = PANEL_W - PAD;

export type Rect = { x: number; y: number; w: number; h: number };
export type Point = { x: number; y: number };

export function centre(rect: Rect): Point {
  return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 };
}

export function contains(rect: Rect, point: Point | null): boolean {
  if (point === null) {
    return false;
  }
  const insideX = point.x >= rect.x && point.x <= rect.x + rect.w;
  const insideY = point.y >= rect.y && point.y <= rect.y + rect.h;
  return insideX && insideY;
}

/** A panel point on the desktop. */
export function toDesktop(point: Point): Point {
  return { x: point.x + PANEL_X, y: point.y };
}

export function notchRect(): Rect {
  return { x: (DESKTOP_W - NOTCH_W) / 2, y: 0, w: NOTCH_W, h: NOTCH_H };
}

// Title row

export const FILTERS = ["All", "Text", "Images", "Saved"] as const;
export type Filter = (typeof FILTERS)[number];

export function segmentRects(titles: readonly string[], x: number, y: number): Rect[] {
  const rects: Rect[] = [];
  let left = x + 2;
  for (const title of titles) {
    const width = labelWidths[title] + 22;
    rects.push({ x: left, y: y + 2, w: width, h: 26 });
    left += width + 2;
  }
  return rects;
}

export function filterRects(): Rect[] {
  return segmentRects(FILTERS, PAD, TOP);
}

export const ICONS = ["palette", "select", "trash", "gear"] as const;
export type IconName = (typeof ICONS)[number];

export function iconRect(name: IconName): Rect {
  const index = ICONS.indexOf(name);
  const fromRight = ICONS.length - 1 - index;
  const x = RIGHT - 28 - fromRight * 32;
  return { x, y: TOP + 1, w: 28, h: 28 };
}

// Accent picker row (only while open)

export const PICKER_Y = TOP + 30 + 10;
export const PICKER_H = 40;

export function swatchRect(index: number): Rect {
  const x = PAD + 10 + index * 28;
  return { x, y: PICKER_Y + 10, w: 20, h: 20 };
}

export function resetRect(): Rect {
  return { x: RIGHT - 10 - 28, y: PICKER_Y + 6, w: 28, h: 28 };
}

export function hueBarRect(): Rect {
  const left = swatchRect(6).x + 20 + 8;
  const right = resetRect().x - 8;
  return { x: left, y: PICKER_Y + 8, w: right - left, h: 24 };
}

// Search row with category tabs

export function searchTop(pickerOpen: boolean): number {
  if (pickerOpen) {
    return PICKER_Y + PICKER_H + 10;
  }
  return PICKER_Y;
}

export const CHEVRON_W = 9.04;

export function tabWidth(title: string, chevron: boolean): number {
  const text = Math.min(92, Math.ceil(labelWidths[title]) + 1);
  let width = text + 10;
  if (chevron) {
    width += 3 + CHEVRON_W;
  }
  return width;
}

export type TabSpec = { key: string; title: string; chevron: boolean };

export function tabRects(tabs: TabSpec[], top: number): Rect[] {
  let total = 0;
  for (const tab of tabs) {
    total += tabWidth(tab.title, tab.chevron);
  }
  total += (tabs.length - 1) * 2;
  let left = RIGHT - total;
  const rects: Rect[] = [];
  for (const tab of tabs) {
    const width = tabWidth(tab.title, tab.chevron);
    rects.push({ x: left, y: top, w: width, h: 34 });
    left += width + 2;
  }
  return rects;
}

export function searchRect(tabs: TabSpec[], top: number): Rect {
  const first = tabRects(tabs, top)[0];
  return { x: PAD, y: top, w: first.x - 8 - PAD, h: 34 };
}

// List

export function listTop(pickerOpen: boolean): number {
  return searchTop(pickerOpen) + 34 + 10;
}

export function listBottom(selecting: boolean): number {
  if (selecting) {
    return SELECT_BAR_Y - 10;
  }
  return PANEL_H - 12;
}

export const ROW_TEXT_H = 57;
export const ROW_IMAGE_H = 60;
export const ROW_GAP = 6;

export function bookmarkRect(row: Rect): Rect {
  return { x: row.x + row.w - 8 - 28, y: row.y + row.h / 2 - 16, w: 28, h: 32 };
}

export function pickBoxRect(row: Rect): Rect {
  return { x: row.x + row.w - 13 - 18, y: row.y + row.h / 2 - 9, w: 18, h: 18 };
}

// Select bar

export const SELECT_BAR_Y = PANEL_H - 12 - 43;

export function selectButtonRect(which: "cancel" | "done"): Rect {
  const y = SELECT_BAR_Y + 5 + 19 - 13;
  if (which === "done") {
    return { x: RIGHT - 72, y, w: 72, h: 26 };
  }
  return { x: RIGHT - 72 - 8 - 72, y, w: 72, h: 26 };
}

// Dropdowns

export const DROPDOWN_W = 196;

export function dropdownOrigin(button: Rect): Point {
  return { x: button.x + button.w - DROPDOWN_W, y: button.y + button.h + 4 };
}

/** Rows of a dropdown: "row" is 28 tall, "switch" 30, "divider" 9. Padding 5 at top and bottom. */
export function dropdownRows(origin: Point, kinds: ("row" | "switch" | "divider")[]): Rect[] {
  let y = origin.y + 5;
  const rects: Rect[] = [];
  for (const kind of kinds) {
    let height = 28;
    if (kind === "switch") {
      height = 30;
    }
    if (kind === "divider") {
      height = 9;
    }
    rects.push({ x: origin.x + 5, y, w: DROPDOWN_W - 10, h: height });
    y += height;
  }
  return rects;
}

export function dropdownHeight(rows: Rect[], origin: Point): number {
  const last = rows[rows.length - 1];
  return last.y + last.h + 5 - origin.y;
}

// Category editor sheet

export const EDITOR_W = 380;
export const EDITOR_ROW_H = 26;
export const EDITOR_ROW_GAP = 6;

export function editorHeight(rowCount: number, canAdd: boolean): number {
  const shown = Math.min(rowCount, 6);
  let rows = shown * EDITOR_ROW_H + Math.max(shown - 1, 0) * EDITOR_ROW_GAP;
  if (rowCount > 6) {
    rows += EDITOR_ROW_GAP + EDITOR_ROW_H / 2;
  }
  let height = 16 + 30 + 10 + 1 + 10 + rows + 10 + 28 + 16;
  if (canAdd) {
    height += 26 + 10;
  }
  return height;
}

export function editorFrame(rowCount: number): Rect {
  const height = editorHeight(rowCount, rowCount < 10);
  const middle = NOTCH_H + (PANEL_H - NOTCH_H) / 2;
  return { x: (PANEL_W - EDITOR_W) / 2, y: middle - height / 2, w: EDITOR_W, h: height };
}

export function editorRowsTop(frame: Rect): number {
  return frame.y + 16 + 30 + 10 + 1 + 10;
}

export function editorRowY(frame: Rect, index: number): number {
  return editorRowsTop(frame) + index * (EDITOR_ROW_H + EDITOR_ROW_GAP);
}

export function editorHandleRect(frame: Rect, index: number): Rect {
  return { x: frame.x + 16, y: editorRowY(frame, index), w: 22, h: EDITOR_ROW_H };
}

export function editorFieldRect(frame: Rect, index: number): Rect {
  const x = frame.x + 16 + 22 + 8;
  const right = frame.x + frame.w - 16 - 24 - 8;
  return { x, y: editorRowY(frame, index), w: right - x, h: EDITOR_ROW_H };
}

export function editorAddRect(frame: Rect, rowCount: number): Rect {
  const shown = Math.min(rowCount, 6);
  const rows = shown * EDITOR_ROW_H + Math.max(shown - 1, 0) * EDITOR_ROW_GAP;
  return { x: frame.x + 16, y: editorRowsTop(frame) + rows + 10, w: 140, h: 26 };
}

export function editorDoneRect(frame: Rect): Rect {
  return { x: frame.x + frame.w - 16 - 76, y: frame.y + frame.h - 16 - 28, w: 76, h: 28 };
}

// The editor window on the desktop

export const DOC = {
  x: 356,
  y: 150,
  w: 800,
  h: 540,
  titleBar: 52,
  textX: 356 + 40,
  headingY: 150 + 52 + 34,
  lineY: (index: number) => 150 + 52 + 92 + index * 40,
};

// The widget that gets screenshotted
export const WIDGET = { x: 70, y: 400, w: 236, h: 170 };
