// Renders single frames for checking: node scripts/stills.mjs <outDir> <seconds...>
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import path from "node:path";

const [outDir, ...times] = process.argv.slice(2);
const serveUrl = await bundle({ entryPoint: path.resolve("src/index.ts") });
const composition = await selectComposition({ serveUrl, id: "Demo" });
for (const time of times) {
  const frame = Math.round(Number(time) * composition.fps);
  const output = path.join(outDir, `t${time}.png`);
  await renderStill({ serveUrl, composition, frame, output, scale: 0.5 });
  console.log(output);
}
