import test from "node:test";
import assert from "node:assert/strict";
import { validateProject } from "../src/index.js";
test("rejects an animation that leaves its scene", () => {
  const issues = validateProject({ version: 1, project: { width: 1920, height: 1080, fps: 30 }, scenes: [{ id: "a", duration: 1, objects: [{ id: "sun", kind: "svg", asset: "sun.svg", x: 0, y: 0, animations: [{ type: "draw", start: 0, duration: 2 }] }] }] });
  assert.equal(issues.length, 1);
});
