import React from "react";
import { Composition, continueRender, delayRender, staticFile } from "remotion";
import { Demo } from "./Demo";
import { FPS, VIDEO_H, VIDEO_W } from "./layout";
import { story } from "./story";

// The app's own fonts, copied from /System/Library/Fonts (not checked in).
const waitForFonts = delayRender("Loading fonts");
const fonts = [
  new FontFace("SFRounded", `url(${staticFile("fonts/SFNSRounded.ttf")})`, { weight: "100 900" }),
  new FontFace("SFPro", `url(${staticFile("fonts/SFNS.ttf")})`, { weight: "100 900" }),
];
Promise.all(fonts.map((font) => font.load())).then((loaded) => {
  for (const font of loaded) {
    document.fonts.add(font);
  }
  continueRender(waitForFonts);
});

export const Root: React.FC = () => {
  return (
    <Composition
      id="Demo"
      component={Demo}
      durationInFrames={Math.ceil(story.duration * FPS)}
      fps={FPS}
      width={VIDEO_W}
      height={VIDEO_H}
    />
  );
};
