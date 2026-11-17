import React from "react";
import { staticFile } from "remotion";
import sizes from "../public/symbols/symbols.json";

type SymbolName = keyof typeof sizes;

/** An SF Symbol exported by scripts/symbols.swift, tinted like SwiftUI's foregroundStyle. */
export const Symbol: React.FC<{ name: SymbolName; size: number; color: string; style?: React.CSSProperties }> = ({
  name,
  size,
  color,
  style,
}) => {
  const [width, height] = sizes[name];
  const scale = size / 100;
  const mask = `url(${staticFile(`symbols/${name}.png`)})`;
  return (
    <div
      style={{
        width: width * scale,
        height: height * scale,
        backgroundColor: color,
        WebkitMaskImage: mask,
        maskImage: mask,
        WebkitMaskSize: "100% 100%",
        maskSize: "100% 100%",
        flexShrink: 0,
        ...style,
      }}
    />
  );
};
