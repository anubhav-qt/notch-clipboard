// The story of the video: what the pointer does, when, and what the app shows.
// Everything is a pure function of time, so any frame can be drawn on its own.
import {
  DOC, Filter, Point, Rect, TabSpec, WIDGET, centre, editorAddRect, editorDoneRect, editorFieldRect,
  editorFrame, editorHandleRect, EDITOR_ROW_GAP, EDITOR_ROW_H, dropdownOrigin, dropdownRows, filterRects,
  hueBarRect, iconRect, listTop, notchRect, PANEL_H, PANEL_X, pickBoxRect, bookmarkRect, PAD, RIGHT,
  ROW_GAP, ROW_IMAGE_H, ROW_TEXT_H, searchRect, searchTop, selectButtonRect, swatchRect, tabRects, resetRect,
  toDesktop, PANEL_W,
} from "./layout";
import { accents, hueColor, RGB } from "./theme";

export type Kind = "Text" | "Link" | "Image";
export type Thumb = "chart" | "sunset" | "sketch";

export type Clip = {
  id: string;
  kind: Kind;
  text: string;
  /** The model's title for an image; until then images read "Copied image / screenshot". */
  title: string | null;
  titleAt: number;
  cat: string | null;
  catAt: number;
  saved: boolean;
  savedAt: number;
  age: string;
  thumb?: Thumb;
};

export type Category = { id: string; name: string };

export type Editor = {
  rows: Category[];
  focus: string | null;
  allSelected: boolean;
  drag: { id: string; start: number; startY: number } | null;
};

export type State = {
  panelOpen: boolean;
  panelAt: number;
  filter: Filter;
  categoryId: string | null;
  query: string;
  searchFocus: boolean;
  listAt: number;
  menu: null | "more" | "settings";
  menuAt: number;
  picker: boolean;
  accent: RGB;
  accentFrom: RGB;
  accentAt: number;
  hueDrag: boolean;
  selecting: boolean;
  picks: string[];
  pickAt: number;
  note: string | null;
  noteAt: number;
  editor: Editor | null;
  editorAt: number;
  categories: Category[];
  clips: Clip[];
  savedOrder: string[];
  reorder: boolean;
  reorderAt: number;
  docSelect: { from: number; to: number } | null;
  docCaret: null | "repo" | "post";
  repo: string;
  repoAt: number;
  post: string;
  postAt: number;
  crosshair: boolean;
  shot: { from: Point; startAt: number; endAt: number; flashAt: number } | null;
};

const IMAGE_FALLBACK = "Copied image / screenshot";

const startingCategories: Category[] = [
  { id: "work", name: "Work" },
  { id: "personal", name: "Personal" },
  { id: "creative", name: "Creative" },
  { id: "reference", name: "Reference" },
];

function clip(id: string, kind: Kind, text: string, cat: string | null, age: string, thumb?: Thumb): Clip {
  return { id, kind, text, title: null, titleAt: -10, cat, catAt: -10, saved: false, savedAt: -10, age, thumb };
}

const LINK = "https://github.com/anubhav-qt/notch-clipboard";
const SHIP = "Ship Notch Clipboard v1 on Friday.";
const TAGLINE = "Hover the notch. Your clipboard is right there.";

function startingState(): State {
  const sunset = clip("sunset", "Image", "", "personal", "25 min ago", "sunset");
  sunset.title = "Sunset over the harbour";
  const sketch = clip("sketch", "Image", "", "creative", "1 hour ago", "sketch");
  sketch.title = "Onboarding screen sketch";
  return {
    panelOpen: false,
    panelAt: -10,
    filter: "All",
    categoryId: null,
    query: "",
    searchFocus: false,
    listAt: -10,
    menu: null,
    menuAt: -10,
    picker: false,
    accent: accents.purple,
    accentFrom: accents.purple,
    accentAt: -10,
    hueDrag: false,
    selecting: false,
    picks: [],
    pickAt: -10,
    note: null,
    noteAt: -10,
    editor: null,
    editorAt: -10,
    categories: startingCategories,
    clips: [
      clip("link", "Link", LINK, "reference", "4 min ago"),
      clip("tagline", "Text", TAGLINE, "creative", "8 min ago"),
      clip("paneer", "Text", "Paneer tikka: 400 g paneer, 1 cup yogurt, 2 tsp garam masala", "personal", "12 min ago"),
      sunset,
      clip("invoice", "Text", "Invoice #2041 due 30 Nov", "work", "40 min ago"),
      sketch,
      clip("mum", "Text", "Call Mum on Sunday", "personal", "2 hours ago"),
    ],
    savedOrder: [],
    reorder: false,
    reorderAt: -10,
    docSelect: null,
    docCaret: null,
    repo: "",
    repoAt: -10,
    post: "",
    postAt: -10,
    crosshair: false,
    shot: null,
  };
}

// What the list shows for a state, in the app's order.

export function clipTitle(item: Clip): string {
  if (item.kind === "Image") {
    return item.title ?? IMAGE_FALLBACK;
  }
  return item.text;
}

export function visibleClips(state: State): Clip[] {
  let candidates = state.clips;
  if (state.filter === "Text") {
    candidates = state.clips.filter((item) => item.kind !== "Image");
  }
  if (state.filter === "Images") {
    candidates = state.clips.filter((item) => item.kind === "Image");
  }
  if (state.filter === "Saved") {
    candidates = [];
    for (const id of state.savedOrder) {
      const found = state.clips.find((item) => item.id === id);
      if (found) {
        candidates.push(found);
      }
    }
  }
  const query = state.query.toLowerCase();
  return candidates.filter((item) => {
    if (state.categoryId !== null && item.cat !== state.categoryId) {
      return false;
    }
    if (query === "") {
      return true;
    }
    const haystack = `${clipTitle(item)} ${item.kind}`.toLowerCase();
    return haystack.includes(query);
  });
}

export function rowRects(items: Clip[], top: number): Rect[] {
  const rects: Rect[] = [];
  let y = top;
  for (const item of items) {
    let height = ROW_TEXT_H;
    if (item.kind === "Image") {
      height = ROW_IMAGE_H;
    }
    rects.push({ x: PAD, y, w: RIGHT - PAD, h: height });
    y += height + ROW_GAP;
  }
  return rects;
}

export function tabsFor(categories: Category[]): TabSpec[] {
  const tabs: TabSpec[] = [{ key: "all", title: "All", chevron: false }];
  for (const category of categories.slice(0, 3)) {
    tabs.push({ key: category.id, title: category.name, chevron: false });
  }
  tabs.push({ key: "more", title: "More", chevron: true });
  return tabs;
}

// The timeline

type Apply = (state: State, time: number) => void;
type Event = { t: number; apply: Apply };
export type CursorKey = { t: number; x: number; y: number };
export type Caption = { from: number; to: number; title: string; sub?: string };
export type Keycap = { from: number; to: number; keys: string[] };
export type CameraKey = { t: number; zoomed: boolean };

class Director {
  now = 0;
  events: Event[] = [];
  cursor: CursorKey[] = [];
  clicks: number[] = [];
  presses: { from: number; to: number }[] = [];
  captions: Caption[] = [];
  keycaps: Keycap[] = [];
  camera: CameraKey[] = [{ t: 0, zoomed: false }];
  private openCaption: Caption | null = null;
  position: Point;

  constructor(start: Point) {
    this.position = start;
    this.cursor.push({ t: 0, ...start });
  }

  at(apply: Apply, delay = 0) {
    this.events.push({ t: this.now + delay, apply });
  }

  wait(seconds: number) {
    this.now += seconds;
  }

  /** Glides to a desktop point; longer trips take a little longer. */
  glide(target: Point, seconds?: number) {
    const distance = Math.hypot(target.x - this.position.x, target.y - this.position.y);
    let duration = seconds ?? 0.26 + distance * 0.0009;
    duration = Math.min(duration, 0.85);
    this.cursor.push({ t: this.now, ...this.position });
    this.now += duration;
    this.cursor.push({ t: this.now, ...target });
    this.position = target;
  }

  /** Glides to a point on the panel. */
  to(point: Point, seconds?: number) {
    this.glide(toDesktop(point), seconds);
  }

  click(apply?: Apply) {
    this.clicks.push(this.now);
    if (apply) {
      this.at(apply, 0.05);
    }
    this.wait(0.14);
  }

  caption(title: string, sub?: string) {
    this.endCaption();
    this.openCaption = { from: this.now, to: this.now + 100, title, sub };
    this.captions.push(this.openCaption);
  }

  endCaption() {
    if (this.openCaption) {
      this.openCaption.to = this.now;
      this.openCaption = null;
    }
  }

  keys(keys: string[], seconds = 0.9) {
    this.keycaps.push({ from: this.now, to: this.now + seconds, keys });
  }

  zoom(zoomed: boolean) {
    this.camera.push({ t: this.now, zoomed });
  }

  type(text: string, apply: (state: State, typed: string, time: number) => void, perKey = 0.075) {
    for (let index = 1; index <= text.length; index += 1) {
      const typed = text.slice(0, index);
      this.at((state, time) => apply(state, typed, time));
      this.wait(perKey);
    }
  }
}

function openPanel(state: State, time: number) {
  state.panelOpen = true;
  state.panelAt = time;
}

function closePanel(state: State, time: number) {
  state.panelOpen = false;
  state.panelAt = time;
  state.menu = null;
}

function setAccent(state: State, color: RGB, time: number) {
  state.accentFrom = state.accent;
  state.accent = color;
  state.accentAt = time;
}

function listChanged(state: State, time: number) {
  state.listAt = time;
}

function findClip(state: State, id: string): Clip {
  const found = state.clips.find((item) => item.id === id);
  if (!found) {
    throw new Error(`No clip ${id}`);
  }
  return found;
}

export type Story = {
  duration: number;
  stateAt: (t: number) => State;
  cursor: CursorKey[];
  clicks: number[];
  presses: { from: number; to: number }[];
  captions: Caption[];
  keycaps: Keycap[];
  camera: CameraKey[];
  cursorHidden: { from: number; to: number }[];
  outroAt: number;
};

/** A panel point for a rect's centre. */
function mid(rect: Rect): Point {
  return centre(rect);
}

export function buildStory(): Story {
  const d = new Director({ x: 980, y: 560 });
  const allTabs = tabsFor(startingCategories);
  const top = searchTop(false);
  const rows = (state: Partial<State> & { clips: Clip[] }) => rowRects(visibleClips(state as State), listTop(false));
  // A copy of the starting list with the two new clips, used to aim at rows.
  const base = startingState();
  const chart = clip("chart", "Image", "", null, "Just now", "chart");
  const ship = clip("ship", "Text", SHIP, null, "Just now");
  const fullList = { ...base, clips: [chart, ship, ...base.clips] };
  const allRows = rows(fullList);
  const indexOf = (id: string) => fullList.clips.findIndex((item) => item.id === id);

  // 0. Title over the desktop.
  d.wait(2.6);

  // 1. Copy a sentence in the editor.
  const lineStart = { x: DOC.textX - 1, y: DOC.lineY(0) + 9 };
  const lineEnd = { x: DOC.textX + 234.8, y: DOC.lineY(0) + 9 };
  d.caption("Copy as usual.", "Notch Clipboard keeps every copy.");
  d.glide(lineStart, 0.8);
  d.wait(0.15);
  const selectFrom = d.now;
  d.presses.push({ from: d.now, to: d.now + 0.75 });
  d.glide(lineEnd, 0.75);
  d.at((state) => {
    state.docSelect = { from: selectFrom, to: selectFrom + 0.75 };
  }, -0.75);
  d.wait(0.25);
  d.keys(["⌘", "C"]);
  d.at((state) => {
    state.clips = [{ ...ship, catAt: -10 }, ...state.clips];
  }, 0.2);
  d.wait(1.0);

  // 2. A screenshot of the widget, straight to the clipboard.
  d.caption("Screenshots too.", "⌘⇧4 copies the region you drag.");
  d.at((state) => {
    state.docSelect = null;
  });
  d.keys(["⌘", "⇧", "4"]);
  d.wait(0.35);
  d.at((state) => {
    state.crosshair = true;
  });
  const shotFrom = { x: WIDGET.x - 14, y: WIDGET.y - 14 };
  const shotTo = { x: WIDGET.x + WIDGET.w + 14, y: WIDGET.y + WIDGET.h + 14 };
  d.glide(shotFrom, 0.6);
  d.wait(0.1);
  const shotStart = d.now;
  d.presses.push({ from: d.now, to: d.now + 0.8 });
  d.glide(shotTo, 0.8);
  const shotEnd = d.now;
  d.at((state) => {
    state.shot = { from: shotFrom, startAt: shotStart, endAt: shotEnd, flashAt: shotEnd };
  }, shotStart - shotEnd);
  d.at((state) => {
    state.crosshair = false;
    state.clips = [{ ...chart }, ...state.clips];
  }, 0.05);
  d.wait(0.9);
  d.at((state) => {
    state.shot = null;
  });

  // 3. Hover the notch.
  d.caption("Hover the notch.", "Your clipboard history drops down from it.");
  const notch = centre(notchRect());
  d.glide({ x: notch.x + 6, y: 12 }, 0.85);
  d.at((state, time) => openPanel(state, time));
  const openTime = d.now;
  d.zoom(true);
  d.wait(0.35);
  d.to(mid(allRows[1]), 0.8);
  d.wait(0.5);

  // 4. Sorting on the Mac.
  d.caption("Sorted on your Mac.", "Apple Intelligence files each clip. On macOS 27, images get a title too.");
  d.at((state) => {
    const item = findClip(state, "chart");
    item.title = "Weekly signups chart";
    item.titleAt = openTime + 1.6;
    item.cat = "work";
    item.catAt = openTime + 1.6;
  }, openTime + 1.6 - d.now);
  d.at((state) => {
    const item = findClip(state, "ship");
    item.cat = "work";
    item.catAt = openTime + 2.3;
  }, openTime + 2.3 - d.now);
  d.to(mid(allRows[0]), 0.7);
  d.wait(1.0);
  d.to({ x: 300, y: allRows[1].y + 30 }, 0.6);
  d.wait(0.7);

  // 5. Save two clips.
  d.caption("Save what you reuse.", "Saved clips stay after a restart.");
  d.to(mid(bookmarkRect(allRows[indexOf("link")])));
  d.wait(0.3);
  d.click((state, time) => {
    const item = findClip(state, "link");
    item.saved = true;
    item.savedAt = time;
    state.savedOrder = ["link", ...state.savedOrder];
  });
  d.wait(0.35);
  d.to(mid(bookmarkRect(allRows[indexOf("tagline")])));
  d.wait(0.25);
  d.click((state, time) => {
    const item = findClip(state, "tagline");
    item.saved = true;
    item.savedAt = time;
    state.savedOrder = ["tagline", ...state.savedOrder];
  });
  d.wait(0.7);

  // 6. Filters.
  d.caption("All, Text, Images, Saved.", "One click narrows the list.");
  const filters = filterRects();
  const pickFilter = (index: number, filter: Filter) => {
    d.to(mid(filters[index]));
    d.wait(0.12);
    const time = d.now;
    d.click((state) => {
      state.filter = filter;
      listChanged(state, time);
    });
    d.wait(0.6);
  };
  pickFilter(1, "Text");
  pickFilter(2, "Images");
  pickFilter(3, "Saved");
  d.wait(0.2);
  pickFilter(0, "All");

  // 7. Category tabs.
  d.caption("A tab for each category.", "Right beside search.");
  const tabs = tabRects(allTabs, top);
  const pickTab = (index: number, id: string | null) => {
    d.to(mid(tabs[index]));
    d.wait(0.12);
    const time = d.now;
    d.click((state) => {
      state.categoryId = id;
      listChanged(state, time);
    });
    d.wait(0.7);
  };
  pickTab(1, "work");
  pickTab(2, "personal");
  pickTab(0, null);

  // 8. Search.
  d.caption("Search as you type.");
  const search = searchRect(allTabs, top);
  d.to({ x: search.x + 60, y: search.y + 17 });
  d.click((state) => {
    state.searchFocus = true;
  });
  d.wait(0.2);
  d.type("invoice", (state, typed, time) => {
    state.query = typed;
    listChanged(state, time);
  }, 0.09);
  d.wait(0.3);
  const clearButton = { x: search.x + search.w - 11 - 7, y: search.y + 17 };
  d.to(clearButton, 0.6);
  d.wait(0.5);
  d.click((state) => {
    state.query = "";
    state.searchFocus = false;
  });
  d.at((state, time) => listChanged(state, time - 0.1));
  d.wait(0.5);

  // 9. More menu and the category editor.
  d.caption("Make the categories yours.", "Rename, add, remove or drag them. Up to ten.");
  const more = tabs[4];
  d.to(mid(more));
  d.wait(0.1);
  const moreAt = d.now;
  d.click((state) => {
    state.menu = "more";
    state.menuAt = moreAt + 0.05;
  });
  d.wait(0.45);
  const moreRows = dropdownRows(dropdownOrigin(more), ["row", "divider", "row"]);
  d.to(mid(moreRows[2]));
  d.wait(0.3);
  const editorOpenAt = d.now;
  d.click((state) => {
    state.menu = null;
    state.editor = { rows: state.categories.map((item) => ({ ...item })), focus: null, allSelected: false, drag: null };
    state.editorAt = editorOpenAt + 0.05;
  });
  d.wait(0.5);

  // Rename Creative to Design.
  let frame = editorFrame(4);
  const creativeField = editorFieldRect(frame, 2);
  d.to({ x: creativeField.x + 80, y: creativeField.y + 13 });
  d.wait(0.1);
  d.click((state) => {
    state.editor!.focus = "creative";
  });
  d.wait(0.2);
  d.keys(["⌘", "A"], 0.6);
  d.at((state) => {
    state.editor!.allSelected = true;
  }, 0.1);
  d.wait(0.5);
  d.type("Design", (state, typed) => {
    state.editor!.allSelected = false;
    state.editor!.rows[2].name = typed;
  }, 0.085);
  d.wait(0.4);

  // Add Recipes.
  const add = editorAddRect(frame, 4);
  d.to({ x: add.x + 50, y: add.y + 13 });
  d.wait(0.1);
  d.click((state) => {
    state.editor!.rows.push({ id: "recipes", name: "" });
    state.editor!.focus = "recipes";
  });
  d.wait(0.5);
  d.type("Recipes", (state, typed) => {
    state.editor!.rows[4].name = typed;
  }, 0.085);
  d.wait(0.45);

  // Drag Reference up two places.
  frame = editorFrame(5);
  const handle = editorHandleRect(frame, 3);
  d.to(mid(handle));
  d.wait(0.3);
  const pitch = EDITOR_ROW_H + EDITOR_ROW_GAP;
  const dragStartY = mid(handle).y;
  d.at((state) => {
    state.editor!.focus = null;
    state.editor!.drag = { id: "reference", start: 3, startY: dragStartY };
  });
  d.presses.push({ from: d.now, to: d.now + 0.95 });
  d.to({ x: mid(handle).x, y: dragStartY - pitch * 2 }, 0.9);
  d.wait(0.05);
  d.at((state) => {
    const editor = state.editor!;
    const moved = editor.rows.splice(3, 1)[0];
    editor.rows.splice(1, 0, moved);
    editor.drag = null;
  });
  d.wait(0.5);

  // Done: the list is saved and every clip is sorted again, newest first.
  const done = editorDoneRect(frame);
  d.to(mid(done));
  d.wait(0.2);
  const savedAt = d.now;
  d.click((state) => {
    state.categories = state.editor!.rows.map((item) => ({ ...item }));
    state.editor = null;
    state.editorAt = savedAt + 0.05;
    for (const item of state.clips) {
      item.cat = null;
      item.catAt = savedAt;
    }
  });
  d.caption("New category? Everything is sorted again.", "Recipes now gets the paneer tikka.");
  const resorted: Record<string, string> = {
    chart: "work", ship: "work", link: "reference", tagline: "creative", paneer: "recipes",
    sunset: "personal", invoice: "work", sketch: "creative", mum: "personal",
  };
  const order = ["chart", "ship", "link", "tagline", "paneer", "sunset", "invoice", "sketch", "mum"];
  order.forEach((id, index) => {
    const time = savedAt + 0.5 + index * 0.22;
    d.at((state) => {
      const item = findClip(state, id);
      item.cat = resorted[id];
      item.catAt = time;
    }, time - d.now);
  });
  d.to({ x: 330, y: allRows[4].y + 20 }, 1.0);
  d.wait(1.9);

  // 10. Click to copy, paste in the editor.
  d.caption("Click to copy. ⌘V to paste.", "The panel closes so you can paste.");
  const linkRow = allRows[indexOf("link")];
  d.to({ x: 250, y: linkRow.y + 28 });
  d.wait(0.2);
  d.click((state, time) => closePanel(state, time));
  d.zoom(false);
  d.wait(0.3);
  const repoEnd = { x: DOC.textX + 43.4 + 2, y: DOC.lineY(1) + 9 };
  d.glide(repoEnd, 0.9);
  d.wait(0.1);
  d.click((state) => {
    state.docCaret = "repo";
  });
  d.wait(0.25);
  d.keys(["⌘", "V"]);
  const repoPaste = d.now + 0.2;
  d.at((state) => {
    state.repo = LINK;
    state.repoAt = repoPaste;
  }, 0.2);
  d.wait(1.15);

  // 11. Select mode.
  d.caption("Pick several, paste once.", "Text joins with a space. Images go as separate items.");
  d.glide({ x: notch.x - 4, y: 12 }, 0.8);
  d.at((state, time) => {
    state.docCaret = null;
    openPanel(state, time);
  });
  d.zoom(true);
  d.wait(0.35);
  d.to(mid(iconRect("select")), 0.75);
  d.wait(0.15);
  d.click((state) => {
    state.selecting = true;
    state.picks = [];
  });
  d.wait(0.4);
  const pick = (id: string) => {
    d.to({ x: 300, y: mid(allRows[indexOf(id)]).y });
    d.wait(0.1);
    const time = d.now;
    d.click((state) => {
      state.picks = [...state.picks, id];
      state.pickAt = time;
    });
    d.wait(0.45);
  };
  pick("tagline");
  pick("ship");
  d.to({ x: 320, y: mid(allRows[0]).y });
  d.wait(0.1);
  const noteAt = d.now;
  d.click((state) => {
    state.note = "Images can't be selected with text";
    state.noteAt = noteAt;
  });
  d.wait(1.05);
  d.to(mid(selectButtonRect("done")), 0.7);
  d.wait(0.2);
  d.click((state, time) => {
    state.selecting = false;
    state.picks = [];
    state.note = null;
    closePanel(state, time);
  });
  d.zoom(false);
  d.wait(0.3);
  const postEnd = { x: DOC.textX + 38.7 + 2, y: DOC.lineY(2) + 9 };
  d.glide(postEnd, 0.9);
  d.wait(0.1);
  d.click((state) => {
    state.docCaret = "post";
  });
  d.wait(0.25);
  d.keys(["⌘", "V"]);
  const postPaste = d.now + 0.2;
  d.at((state) => {
    state.post = `${TAGLINE} ${SHIP}`;
    state.postAt = postPaste;
  }, 0.2);
  d.wait(1.35);

  // 12. Accent colour.
  d.caption("Your colour.", "Every accent in the panel follows it.");
  d.glide({ x: notch.x + 2, y: 12 }, 0.8);
  d.at((state, time) => {
    state.docCaret = null;
    openPanel(state, time);
  });
  d.zoom(true);
  d.wait(0.35);
  d.to(mid(iconRect("palette")), 0.75);
  d.wait(0.15);
  d.click((state) => {
    state.picker = true;
  });
  d.wait(0.4);
  const swatch = (index: number, name: string) => {
    d.to(mid(swatchRect(index)));
    d.wait(0.1);
    const time = d.now;
    d.click((state) => setAccent(state, accents[name], time));
    d.wait(0.45);
  };
  swatch(4, "mint");
  swatch(1, "coral");
  const bar = hueBarRect();
  const hueFrom = 0.55;
  const hueTo = 0.86;
  d.to({ x: bar.x + bar.w * hueFrom, y: bar.y + 12 });
  d.wait(0.1);
  d.at((state) => {
    state.hueDrag = true;
  });
  d.presses.push({ from: d.now, to: d.now + 0.95 });
  d.to({ x: bar.x + bar.w * hueTo, y: bar.y + 12 }, 0.95);
  d.at((state) => {
    state.hueDrag = false;
    state.accent = hueColor(hueTo);
    state.accentFrom = state.accent;
  });
  d.wait(0.5);
  d.to(mid(resetRect()));
  d.wait(0.15);
  const resetAt = d.now;
  d.click((state) => setAccent(state, accents.purple, resetAt));
  d.wait(0.5);
  d.to(mid(iconRect("palette")));
  d.click((state) => {
    state.picker = false;
  });
  d.wait(0.3);

  // 13. Gear menu.
  d.caption("Reorder history, if you like.", "On: a clip you copy again jumps to the top. Off by default.");
  const gear = iconRect("gear");
  d.to(mid(gear));
  d.wait(0.1);
  const gearAt = d.now;
  d.click((state) => {
    state.menu = "settings";
    state.menuAt = gearAt + 0.05;
  });
  d.wait(0.4);
  const settingsRows = dropdownRows(dropdownOrigin(gear), ["switch", "divider", "row"]);
  d.to({ x: settingsRows[0].x + 60, y: mid(settingsRows[0]).y });
  d.wait(0.2);
  const reorderAt = d.now;
  d.click((state) => {
    state.reorder = true;
    state.reorderAt = reorderAt;
  });
  d.wait(1.3);
  d.to({ x: 200, y: allRows[2].y + 20 }, 0.7);
  d.click((state) => {
    state.menu = null;
  });
  d.wait(0.5);

  // 14. Leave the panel; it folds back into the notch.
  d.endCaption();
  d.glide({ x: PANEL_X + 120, y: PANEL_H + 60 }, 0.6);
  d.at((state, time) => closePanel(state, time), -0.25);
  d.zoom(false);
  d.wait(1.3);

  const outroAt = d.now;
  d.wait(4.2);

  const events = d.events.slice().sort((a, b) => a.t - b.t);
  const stateAt = (t: number): State => {
    const state = startingState();
    for (const event of events) {
      if (event.t > t) {
        break;
      }
      event.apply(state, event.t);
    }
    return state;
  };

  return {
    duration: d.now,
    stateAt,
    cursor: d.cursor,
    clicks: d.clicks,
    presses: d.presses,
    captions: d.captions,
    keycaps: d.keycaps,
    camera: d.camera,
    cursorHidden: [{ from: 0, to: 2.4 }, { from: outroAt + 0.2, to: 999 }],
    outroAt,
  };
}

export const PANEL_SIZE = { w: PANEL_W, h: PANEL_H };
export { pickBoxRect };
