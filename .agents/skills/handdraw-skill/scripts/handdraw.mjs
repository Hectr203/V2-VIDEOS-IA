#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const cli = join(root, "packages", "cli", "dist", "index.js");
if (!existsSync(cli)) {
  const build = spawnSync("npm", ["run", "build"], { cwd: root, stdio: "inherit" });
  if (build.status !== 0) process.exit(build.status ?? 1);
}
const bundledPython = join(root, ".venv", "bin", "python");
const result = spawnSync(process.execPath, [cli, ...process.argv.slice(2)], { cwd: root, stdio: "inherit", env: { ...process.env, HANDDRAW_PYTHON: existsSync(bundledPython) ? bundledPython : "python3" } });
process.exit(result.status ?? 1);
