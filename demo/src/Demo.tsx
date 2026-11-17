// One continuous shot: camera, desktop, panel, pointer, captions and key presses.
import React from "react";
import { AbsoluteFill, Easing, useCurrentFrame } from "remotion";
import { EditorWindow, MenuBar, ScreenshotOverlay, Wallpaper, Widget } from "./Desktop";
import { DESKTOP_H, DESKTOP_W, FPS, hueBarRect, notchRect, PANEL_X, Point, VIDEO_W } from "./layout";
import { Panel, progress, revealAmount } from "./Panel";
import { Story } from "./script";
import { story } from "./story";
import { hueColor, mix, rgba, RGB, rounded } from "./theme";

const smooth = Easing.bezier(0.45, 0, 0.25, 1);

function eased(raw: number): number {
  if (raw <= 0) {
    return 0;
  }
  if (raw >= 1) {
    return 1;
  }
  return smooth(raw);
}

export function pointerAt(story: Story, t: number): Point {
  const keys = story.cursor;
  if (t <= keys[0].t) {
    return { x: keys[0].x, y: keys[0].y };
  }
  for (let index = 1; index < keys.length; index += 1) {
    const before = keys[index - 1];
    const after = keys[index];
    if (t <= after.t) {
      const span = after.t - before.t;
      let amount = 1;
      if (span > 0) {
        amount = eased((t - before.t) / span);
      }
      return { x: before.x + (after.x - before.x) * amount, y: before.y + (after.y - before.y) * amount };
    }
  }
  const last = keys[keys.length - 1];
  return { x: last.x, y: last.y };
}

const WIDE = { scale: VIDEO_W / DESKTOP_W, x: 0, y: 0 };
const ZOOM_SCALE = 1.9;
const ZOOM = { scale: ZOOM_SCALE, x: 1330 - (DESKTOP_W / 2) * ZOOM_SCALE, y: 0 };
const CAMERA_SECONDS = 1.1;

function cameraAt(story: Story, t: number) {
  let zoomed = 0;
  for (const key of story.camera) {
    if (key.t > t) {
      break;
    }
    const amount = eased((t - key.t) / CAMERA_SECONDS);
    if (key.zoomed) {
      zoomed = zoomed + (1 - zoomed) * amount;
    } else {
      zoomed = zoomed * (1 - amount);
    }
  }
  return {
    scale: WIDE.scale + (ZOOM.scale - WIDE.scale) * zoomed,
    x: WIDE.x + (ZOOM.x - WIDE.x) * zoomed,
    y: WIDE.y + (ZOOM.y - WIDE.y) * zoomed,
    zoomed,
  };
}

const Cursor: React.FC<{ point: Point; pressed: number; crosshair: boolean }> = ({ point, pressed, crosshair }) => {
  if (crosshair) {
    return (
      <svg style={{ position: "absolute", left: point.x - 11, top: point.y - 11, overflow: "visible" }} width={22} height={22}>
        <path d="M11 0 V22 M0 11 H22" stroke="white" strokeWidth={3} />
        <path d="M11 0 V22 M0 11 H22" stroke="black" strokeWidth={1.2} />
      </svg>
    );
  }
  const scale = 1 - 0.14 * pressed;
  return (
    <svg style={{ position: "absolute", left: point.x - 1, top: point.y - 1, overflow: "visible", transform: `scale(${scale})`, transformOrigin: "1px 1px", filter: "drop-shadow(0 1px 1.5px rgba(0,0,0,0.45))" }} width={20} height={26}>
      <path d="M1 1 L1 19.5 L5.6 15.3 L8.6 22.4 L11.6 21.1 L8.7 14.2 L14.8 14.2 Z" fill="black" stroke="white" strokeWidth={1.4} strokeLinejoin="round" />
    </svg>
  );
};

function pressAmount(story: Story, t: number): number {
  for (const press of story.presses) {
    if (t >= press.from && t <= press.to) {
      return 1;
    }
  }
  let amount = 0;
  for (const click of story.clicks) {
    const since = t - click;
    if (since >= 0 && since < 0.2) {
      amount = Math.max(amount, Math.sin((since / 0.2) * Math.PI));
    }
  }
  return amount;
}

function fadeWindow(t: number, from: number, to: number, fadeIn = 0.35, fadeOut = 0.25): number {
  const showing = progress(t, from + 0.08, fadeIn);
  const hiding = progress(t, to - 0.12, fadeOut);
  return showing * (1 - hiding);
}

const Captions: React.FC<{ story: Story; t: number }> = ({ story, t }) => {
  return (
    <>
      {story.captions.map((caption) => {
        const amount = fadeWindow(t, caption.from, caption.to);
        if (amount <= 0) {
          return null;
        }
        return (
          <div key={caption.from} style={{ position: "absolute", left: 96, bottom: 84, width: 640, opacity: amount, transform: `translateY(${14 * (1 - amount)}px)`, fontFamily: rounded }}>
            <div style={{ fontSize: 50, fontWeight: 700, color: "white", lineHeight: 1.12, textShadow: "0 2px 18px rgba(0,0,0,0.45)" }}>{caption.title}</div>
            {caption.sub ? <div style={{ fontSize: 25, fontWeight: 500, color: "rgba(255,255,255,0.68)", marginTop: 12, lineHeight: 1.3, textShadow: "0 2px 14px rgba(0,0,0,0.5)" }}>{caption.sub}</div> : null}
          </div>
        );
      })}
    </>
  );
};

const Keycaps: React.FC<{ story: Story; t: number }> = ({ story, t }) => {
  return (
    <>
      {story.keycaps.map((keycap) => {
        const amount = fadeWindow(t, keycap.from - 0.08, keycap.to, 0.16, 0.2);
        if (amount <= 0) {
          return null;
        }
        return (
          <div key={keycap.from} style={{ position: "absolute", left: 0, right: 0, bottom: 64, display: "flex", justifyContent: "center", opacity: amount, transform: `scale(${0.92 + 0.08 * amount})` }}>
            <div style={{ display: "flex", gap: 10, padding: 12, borderRadius: 22, background: "rgba(16, 16, 20, 0.82)", boxShadow: "0 12px 40px rgba(0,0,0,0.4), inset 0 0 0 1px rgba(255,255,255,0.1)" }}>
              {keycap.keys.map((key, index) => (
                <div key={index} style={{ minWidth: 58, height: 58, borderRadius: 13, background: "rgba(255,255,255,0.08)", boxShadow: "inset 0 -2px 0 rgba(0,0,0,0.35), inset 0 0 0 1px rgba(255,255,255,0.12)", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: rounded, fontSize: 28, fontWeight: 600, color: "white" }}>
                  {key}
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </>
  );
};

const TitleCard: React.FC<{ amount: number; outro: boolean }> = ({ amount, outro }) => {
  if (amount <= 0) {
    return null;
  }
  return (
    <AbsoluteFill style={{ background: `rgba(6, 5, 14, ${0.7 * amount})`, alignItems: "center", justifyContent: "center", fontFamily: rounded }}>
      <div style={{ opacity: amount, transform: `translateY(${18 * (1 - amount)}px)`, textAlign: "center" }}>
        <div style={{ fontSize: 112, fontWeight: 700, color: "white", letterSpacing: -1 }}>Notch Clipboard</div>
        {outro ? (
          <>
            <div style={{ fontSize: 34, color: "rgba(255,255,255,0.72)", marginTop: 18 }}>Free and open source. macOS 14 or later.</div>
            <div style={{ fontSize: 34, fontWeight: 600, color: "rgb(191, 165, 255)", marginTop: 26 }}>github.com/anubhav-qt/notch-clipboard</div>
          </>
        ) : (
          <div style={{ fontSize: 38, color: "rgba(255,255,255,0.72)", marginTop: 18 }}>Clipboard history that lives in your notch.</div>
        )}
      </div>
    </AbsoluteFill>
  );
};

function accentAt(story: Story, t: number, pointer: Point): RGB {
  const state = story.stateAt(t);
  if (state.hueDrag) {
    const bar = hueBarRect();
    const hue = Math.min(0.999, Math.max(0, (pointer.x - PANEL_X - bar.x) / bar.w));
    return hueColor(hue);
  }
  return mix(state.accentFrom, state.accent, progress(t, state.accentAt, 0.25));
}

export const Demo: React.FC = () => {
  const frame = useCurrentFrame();
  const t = frame / FPS;
  const state = story.stateAt(t);
  const pointer = pointerAt(story, t);
  const camera = cameraAt(story, t);
  const accent = accentAt(story, t, pointer);
  let panelPointer: Point | null = null;
  if (revealAmount(state, t) > 0.9) {
    panelPointer = { x: pointer.x - PANEL_X, y: pointer.y };
  }
  let cursorShown = true;
  for (const hidden of story.cursorHidden) {
    if (t >= hidden.from && t < hidden.to) {
      cursorShown = false;
    }
  }
  const intro = 1 - progress(t, 2.1, 0.5);
  const outro = progress(t, story.outroAt, 0.6);
  const notch = notchRect();
  return (
    <AbsoluteFill style={{ background: "black", overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, top: 0, width: DESKTOP_W, height: DESKTOP_H, transformOrigin: "0 0", transform: `translate(${camera.x}px, ${camera.y}px) scale(${camera.scale})` }}>
        <div style={{ position: "absolute", inset: 0, filter: `blur(${Math.max(5 * camera.zoomed, 8 * Math.max(intro, outro))}px) brightness(${1 - 0.4 * camera.zoomed})` }}>
          <Wallpaper />
          <Widget />
          <EditorWindow state={state} t={t} pointer={pointer} />
          <MenuBar />
        </div>
        <div style={{ position: "absolute", left: PANEL_X, top: 0 }}>
          <Panel state={state} t={t} pointer={panelPointer} accent={accent} />
        </div>
        <div style={{ position: "absolute", left: notch.x, top: 0, width: notch.w, height: 2, background: "black" }} />
        <ScreenshotOverlay state={state} t={t} pointer={pointer} />
        {cursorShown ? <Cursor point={pointer} pressed={pressAmount(story, t)} crosshair={state.crosshair} /> : null}
      </div>
      <AbsoluteFill style={{ background: "linear-gradient(90deg, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0.3) 35%, rgba(0,0,0,0) 48%)", opacity: camera.zoomed }} />
      <Captions story={story} t={t} />
      <Keycaps story={story} t={t} />
      <TitleCard amount={intro} outro={false} />
      <TitleCard amount={outro} outro />
    </AbsoluteFill>
  );
};

export { rgba };
