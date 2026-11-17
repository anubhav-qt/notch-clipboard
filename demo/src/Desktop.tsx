// The Mac around the panel: wallpaper, menu bar, notch, an editor window and a widget.
import React from "react";
import { DESKTOP_H, DESKTOP_W, DOC, MENU_BAR_H, notchRect, Point, WIDGET } from "./layout";
import { State } from "./script";
import { plain } from "./theme";
import { SignupsCard } from "./Thumbnails";
import { progress } from "./Panel";

const CARET = "rgb(52, 120, 246)";
const SELECTION = "rgba(52, 120, 246, 0.42)";
const SHIP = "Ship Notch Clipboard v1 on Friday.";
const SHIP_WIDTH = 234.8;

export const Wallpaper: React.FC = () => {
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: [
          "radial-gradient(60% 70% at 18% 78%, rgba(96, 72, 190, 0.85) 0%, rgba(96, 72, 190, 0) 70%)",
          "radial-gradient(55% 60% at 85% 30%, rgba(40, 120, 160, 0.7) 0%, rgba(40, 120, 160, 0) 70%)",
          "radial-gradient(50% 50% at 60% 95%, rgba(190, 90, 140, 0.55) 0%, rgba(190, 90, 140, 0) 70%)",
          "linear-gradient(160deg, #191433 0%, #120f24 55%, #0c1424 100%)",
        ].join(", "),
      }}
    />
  );
};

export const MenuBar: React.FC = () => {
  const notch = notchRect();
  const item: React.CSSProperties = { fontFamily: plain, fontSize: 13.5, color: "rgba(255,255,255,0.92)", whiteSpace: "nowrap" };
  return (
    <>
      <div style={{ position: "absolute", left: 0, top: 0, width: DESKTOP_W, height: MENU_BAR_H, background: "rgba(10, 8, 22, 0.35)", backdropFilter: "blur(20px)" }} />
      <div style={{ position: "absolute", left: 22, top: 0, height: MENU_BAR_H, display: "flex", alignItems: "center", gap: 22 }}>
        <div style={{ ...item, fontWeight: 700 }}>Editor</div>
        {["File", "Edit", "Format", "View", "Window", "Help"].map((name) => (
          <div key={name} style={item}>
            {name}
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", right: 22, top: 0, height: MENU_BAR_H, display: "flex", alignItems: "center", gap: 18 }}>
        <div style={item}>Tue 17 Nov 10:24</div>
      </div>
      <div style={{ position: "absolute", left: notch.x, top: 0, width: notch.w, height: notch.h, background: "black", borderBottomLeftRadius: 11, borderBottomRightRadius: 11 }} />
    </>
  );
};

function selectionWidth(state: State, t: number, pointer: Point): number {
  if (state.docSelect === null) {
    return 0;
  }
  if (t >= state.docSelect.to) {
    return SHIP_WIDTH;
  }
  const width = pointer.x - DOC.textX;
  return Math.max(0, Math.min(SHIP_WIDTH, width));
}

function blink(t: number): boolean {
  return Math.floor(t * 1.9) % 2 === 0;
}

const Caret: React.FC = () => <div style={{ width: 1.5, height: 19, background: CARET, marginLeft: 1 }} />;

export const EditorWindow: React.FC<{ state: State; t: number; pointer: Point }> = ({ state, t, pointer }) => {
  const line: React.CSSProperties = { position: "absolute", left: DOC.textX - DOC.x, fontFamily: plain, fontSize: 15, color: "rgba(255,255,255,0.88)", height: 18, lineHeight: "18px", whiteSpace: "nowrap", display: "flex", alignItems: "center" };
  const top = (y: number) => y - DOC.y;
  const pasteGlow = (at: number) => {
    const amount = 1 - progress(t, at, 0.7);
    return `rgba(191, 165, 255, ${0.28 * amount})`;
  };
  return (
    <div style={{ position: "absolute", left: DOC.x, top: DOC.y, width: DOC.w, height: DOC.h, borderRadius: 12, background: "rgb(30, 30, 32)", boxShadow: "0 30px 80px rgba(0,0,0,0.55), inset 0 0 0 1px rgba(255,255,255,0.09)", overflow: "hidden" }}>
      <div style={{ height: DOC.titleBar, borderBottom: "1px solid rgba(255,255,255,0.07)", display: "flex", alignItems: "center", paddingLeft: 20, gap: 8, position: "relative" }}>
        {["#ff5f57", "#febc2e", "#28c840"].map((color) => (
          <div key={color} style={{ width: 12, height: 12, borderRadius: 6, background: color }} />
        ))}
        <div style={{ position: "absolute", left: 0, right: 0, textAlign: "center", fontFamily: plain, fontSize: 13, fontWeight: 600, color: "rgba(255,255,255,0.6)" }}>Launch notes.md</div>
      </div>
      <div style={{ ...line, top: top(DOC.headingY), fontSize: 24, fontWeight: 700, height: 30, color: "white" }}>Launch notes</div>
      <div style={{ ...line, top: top(DOC.lineY(0)) }}>
        <div style={{ position: "absolute", left: 0, top: -2, height: 22, width: selectionWidth(state, t, pointer), background: SELECTION, borderRadius: 2 }} />
        <span style={{ position: "relative" }}>{SHIP}</span>
      </div>
      <div style={{ ...line, top: top(DOC.lineY(1)) }}>
        <span style={{ color: "rgba(255,255,255,0.5)" }}>Repo:&nbsp;</span>
        <span style={{ background: pasteGlow(state.repoAt), borderRadius: 3 }}>{state.repo}</span>
        {state.docCaret === "repo" && blink(t) ? <Caret /> : null}
      </div>
      <div style={{ ...line, top: top(DOC.lineY(2)) }}>
        <span style={{ color: "rgba(255,255,255,0.5)" }}>Post:&nbsp;</span>
        <span style={{ background: pasteGlow(state.postAt), borderRadius: 3 }}>{state.post}</span>
        {state.docCaret === "post" && blink(t) ? <Caret /> : null}
      </div>
      <div style={{ ...line, top: top(DOC.lineY(3)) + 18, fontSize: 17, fontWeight: 700, color: "white" }}>Todo</div>
      <div style={{ ...line, top: top(DOC.lineY(4)) + 14 }}>• Record the demo video</div>
      <div style={{ ...line, top: top(DOC.lineY(5)) + 10 }}>• Write the README</div>
      <div style={{ ...line, top: top(DOC.lineY(6)) + 6 }}>• Tag the v1 release</div>
    </div>
  );
};

export const Widget: React.FC = () => {
  return (
    <div style={{ position: "absolute", left: WIDGET.x, top: WIDGET.y }}>
      <SignupsCard />
    </div>
  );
};

export const ScreenshotOverlay: React.FC<{ state: State; t: number; pointer: Point }> = ({ state, t, pointer }) => {
  const shot = state.shot;
  if (shot === null) {
    return null;
  }
  let end = pointer;
  if (t >= shot.endAt) {
    end = { x: WIDGET.x + WIDGET.w + 14, y: WIDGET.y + WIDGET.h + 14 };
  }
  const left = Math.min(shot.from.x, end.x);
  const top = Math.min(shot.from.y, end.y);
  const width = Math.abs(end.x - shot.from.x);
  const height = Math.abs(end.y - shot.from.y);
  const flash = t >= shot.flashAt ? 1 - progress(t, shot.flashAt, 0.45) : 0;
  const dragging = t < shot.endAt;
  return (
    <>
      {dragging ? <div style={{ position: "absolute", left, top, width, height, background: "rgba(200, 200, 210, 0.22)", boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.55)" }} /> : null}
      {flash > 0 ? <div style={{ position: "absolute", left, top, width, height, background: `rgba(255,255,255,${0.75 * flash})` }} /> : null}
    </>
  );
};

export { DESKTOP_H, DESKTOP_W };
