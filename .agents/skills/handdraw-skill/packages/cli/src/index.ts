#!/usr/bin/env node
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { dirname, extname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { synchronizeNarration, validateProject, type HandDrawProject } from "@handdraw/core";
import { renderProject } from "@handdraw/renderer";
import { mixNarration, synthesizeEdgeNarration } from "@handdraw/audio";
import { projectDuration } from "@handdraw/core";
const [command, file, ...args] = process.argv.slice(2);
const usage = () => console.error("Usage: handdraw validate <project.json> | handdraw render <project.json> --output <video.mp4> [--assets <directory>]");
async function main() {
  if (!command || !file || !["validate", "render"].includes(command)) { usage(); process.exitCode = 1; return; }
  let project: HandDrawProject; try { project = JSON.parse(await readFile(resolve(file), "utf8")); } catch (error) { console.error(`Cannot read project: ${error instanceof Error ? error.message : error}`); process.exitCode = 1; return; }
  const issues = validateProject(project); if (issues.length) { issues.forEach((issue) => console.error(`${issue.path}: ${issue.message}`)); process.exitCode = 1; return; }
  if (command === "validate") { console.log("Project is valid."); return; }
  const value = (flag: string) => { const index = args.indexOf(flag); return index === -1 ? undefined : args[index + 1]; };
  const output = value("--output"); if (!output) { usage(); process.exitCode = 1; return; }
  const suppliedAssets = value("--assets"); const assetDirectory = suppliedAssets ? resolve(suppliedAssets) : resolve(dirname(resolve(file)), "assets");
  const outputPath = resolve(output);
  if (!project.audio?.narration.length) { await renderProject(project, outputPath, assetDirectory); console.log(`Rendered ${outputPath}`); return; }
  const temporaryDirectory = await mkdtemp(join(tmpdir(), "handdraw-audio-"));
  try {
    const silentVideo = join(temporaryDirectory, `silent${extname(outputPath) || ".mp4"}`);
    const clips = await synthesizeEdgeNarration(project.audio.narration, temporaryDirectory);
    const timedProject = synchronizeNarration(project, clips.map((clip) => clip.duration));
    await renderProject(timedProject, silentVideo, assetDirectory);
    await mixNarration(silentVideo, clips, outputPath, projectDuration(project));
    console.log(`Rendered ${outputPath} with free Edge TTS narration.`);
  } finally { await rm(temporaryDirectory, { recursive: true, force: true }); }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
