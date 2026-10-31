#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const python = existsSync(join(root, ".venv", "bin", "python")) ? join(root, ".venv", "bin", "python") : "python3";

const checks = [
  ["Node.js 20+", process.version.match(/^v(\d+)/)?.[1] >= 20, "Install Node.js 20 or newer."],
  ["FFmpeg", spawnSync("ffmpeg", ["-version"]).status === 0, "Install FFmpeg and put it on PATH."],
  ["Python edge-tts", spawnSync(python, ["-m", "edge_tts", "--version"]).status === 0, "Run: python3 -m venv .venv && .venv/bin/pip install -r packages/audio/requirements.txt"],
];
let failed = false;
for (const [name, ok, remedy] of checks) { console.log(`${ok ? "✓" : "✗"} ${name}`); if (!ok) { console.error(`  ${remedy}`); failed = true; } }
process.exitCode = failed ? 1 : 0;
