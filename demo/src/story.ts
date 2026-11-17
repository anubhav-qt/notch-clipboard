import { buildStory } from "./script";

/** Built once; functions can't travel as Remotion props, so views import it. */
export const story = buildStory();
