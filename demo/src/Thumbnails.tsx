// Made-up pictures for the image clips: the signups widget, a sunset photo and a phone sketch.
import React from "react";
import { rounded } from "./theme";

const bars = [38, 52, 44, 61, 58, 74, 88];

/** The desktop widget that gets screenshotted, drawn at 236 x 170. */
export const SignupsCard: React.FC = () => {
  return (
    <div style={{ width: 236, height: 170, borderRadius: 18, background: "rgba(28, 30, 38, 0.92)", boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.08)", padding: "16px 18px", boxSizing: "border-box", fontFamily: rounded, color: "white" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
        <div style={{ fontSize: 13, fontWeight: 600, opacity: 0.85 }}>Weekly signups</div>
        <div style={{ fontSize: 12, fontWeight: 600, color: "rgb(110, 214, 160)" }}>+18%</div>
      </div>
      <div style={{ fontSize: 26, fontWeight: 700, marginTop: 4 }}>1,284</div>
      <div style={{ display: "flex", alignItems: "flex-end", gap: 7, height: 62, marginTop: 8 }}>
        {bars.map((height, index) => (
          <div key={index} style={{ flex: 1, height: `${height}%`, borderRadius: 4, background: index === bars.length - 1 ? "rgb(110, 170, 255)" : "rgba(110, 170, 255, 0.4)" }} />
        ))}
      </div>
    </div>
  );
};

const Sunset: React.FC<{ width: number; height: number }> = ({ width, height }) => {
  return (
    <div style={{ width, height, position: "relative", overflow: "hidden", background: "linear-gradient(180deg, #2b2a6b 0%, #b14d7a 48%, #f39a5a 70%, #1c2b4a 71%, #0f1a30 100%)" }}>
      <div style={{ position: "absolute", left: width * 0.5 - height * 0.17, top: height * 0.5, width: height * 0.34, height: height * 0.34, borderRadius: "50%", background: "#ffd38a" }} />
      <div style={{ position: "absolute", left: 0, right: 0, top: height * 0.71, bottom: 0, background: "linear-gradient(180deg, rgba(255,190,120,0.35), rgba(15,26,48,0))" }} />
    </div>
  );
};

const PhoneSketch: React.FC<{ width: number; height: number }> = ({ width, height }) => {
  const line = "rgba(40, 40, 60, 0.75)";
  return (
    <div style={{ width, height, background: "#f4f1ea", position: "relative" }}>
      <div style={{ position: "absolute", left: width * 0.22, right: width * 0.22, top: height * 0.08, bottom: height * 0.08, border: `1px solid ${line}`, borderRadius: width * 0.08 }}>
        <div style={{ position: "absolute", left: "18%", right: "18%", top: "22%", height: "22%", borderRadius: "50%", border: `1px solid ${line}` }} />
        <div style={{ position: "absolute", left: "15%", right: "15%", top: "56%", height: 1, background: line }} />
        <div style={{ position: "absolute", left: "25%", right: "25%", top: "64%", height: 1, background: line }} />
        <div style={{ position: "absolute", left: "20%", right: "20%", bottom: "10%", height: "10%", borderRadius: 3, background: "rgba(110, 120, 230, 0.8)" }} />
      </div>
    </div>
  );
};

/** A picture fitted inside a square, like SwiftUI's scaledToFit in a 42 x 42 frame. */
export const Thumbnail: React.FC<{ kind: "chart" | "sunset" | "sketch"; size: number; radius: number }> = ({ kind, size, radius }) => {
  let content: React.ReactNode;
  if (kind === "chart") {
    const width = 264;
    const scale = size / width;
    content = (
      <div style={{ width: size, height: 198 * scale, overflow: "hidden", background: "#3a3357", position: "relative" }}>
        <div style={{ position: "absolute", left: 14 * scale, top: 14 * scale, transform: `scale(${scale})`, transformOrigin: "top left" }}>
          <SignupsCard />
        </div>
      </div>
    );
  } else if (kind === "sunset") {
    content = <Sunset width={size} height={size * 0.75} />;
  } else {
    content = <PhoneSketch width={size * 0.75} height={size} />;
  }
  return (
    <div style={{ width: size, height: size, borderRadius: radius, overflow: "hidden", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
      {content}
    </div>
  );
};
