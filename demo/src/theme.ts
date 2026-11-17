// Colours and sizes copied from the app's Theme.swift, AccentColor.swift and components.

export type RGB = [number, number, number];

export const theme = {
  panel: "#000000",
  card: "rgb(20, 20, 20)",
  cardHover: "rgb(28, 28, 28)",
  menu: "rgb(24, 24, 24)",
  line: "rgba(255, 255, 255, 0.08)",
  text: "rgba(255, 255, 255, 0.9)",
  dimText: "rgba(255, 255, 255, 0.5)",
  faintText: "rgba(255, 255, 255, 0.35)",
};

export const accents: Record<string, RGB> = {
  purple: [191, 165, 255],
  coral: [255, 122, 107],
  amber: [242, 166, 90],
  lime: [183, 227, 107],
  mint: [79, 209, 197],
  sky: [110, 170, 255],
  pink: [255, 140, 190],
};

export const presetOrder = ["purple", "coral", "amber", "lime", "mint", "sky", "pink"];

export function rgba(color: RGB, alpha = 1): string {
  return `rgba(${color[0]}, ${color[1]}, ${color[2]}, ${alpha})`;
}

export function mix(from: RGB, to: RGB, amount: number): RGB {
  return [
    from[0] + (to[0] - from[0]) * amount,
    from[1] + (to[1] - from[1]) * amount,
    from[2] + (to[2] - from[2]) * amount,
  ];
}

/** Any hue at the app's soft strength: saturation 0.45, brightness 1. */
export function hueColor(hue: number): RGB {
  const s = 0.45;
  const h = (hue - Math.floor(hue)) * 6;
  const sector = Math.floor(h);
  const f = h - sector;
  const p = 1 - s;
  const q = 1 - s * f;
  const t = 1 - s * (1 - f);
  const table: [number, number, number][] = [
    [1, t, p],
    [q, 1, p],
    [p, 1, t],
    [p, q, 1],
    [t, p, 1],
    [1, p, q],
  ];
  const [r, g, b] = table[sector % 6];
  return [r * 255, g * 255, b * 255];
}

export const rounded = "SFRounded, system-ui";
export const plain = "SFPro, system-ui";

/** Text widths at 12 pt medium, measured with NSFont like TabButton.textWidth. */
export const labelWidths: Record<string, number> = {
  All: 14.67,
  Creative: 47.48,
  Design: 39.51,
  First: 25.3,
  Images: 41.13,
  Last: 24.39,
  More: 28.83,
  Personal: 49.14,
  Recipes: 45.16,
  Reference: 57.55,
  Saved: 35.16,
  Text: 23.66,
  Work: 29.3,
};
