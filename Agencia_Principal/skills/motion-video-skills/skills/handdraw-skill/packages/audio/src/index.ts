import { mkdir } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { join } from "node:path";
import type { NarrationClip } from "@handdraw/core";

const run = promisify(execFile);
export interface SynthesizedClip { path: string; start: number; duration: number; }

async function mediaDuration(path: string): Promise<number> {
  const { stdout } = await run("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", path]);
  const duration = Number.parseFloat(stdout.trim());
  if (!Number.isFinite(duration) || duration <= 0) throw new Error(`Cannot determine narration duration for ${path}`);
  return duration;
}

/** Create natural narration using the free Edge TTS service; no API key is required. */
export async function synthesizeEdgeNarration(clips: NarrationClip[], outputDirectory: string): Promise<SynthesizedClip[]> {
  await mkdir(outputDirectory, { recursive: true });
  const synthesized: SynthesizedClip[] = [];
  for (const [index, clip] of clips.entries()) {
    const path = join(outputDirectory, `narration-${String(index).padStart(3, "0")}.mp3`);
    try {
      await run(process.env.HANDDRAW_PYTHON ?? "python3", ["-m", "edge_tts", "--voice", clip.voice ?? "zh-CN-XiaoxiaoNeural", "--rate", clip.rate ?? "+0%", "--text", clip.text, "--write-media", path]);
    } catch (error) {
      throw new Error(`Edge TTS synthesis failed. Install it with: python3 -m venv .venv && .venv/bin/pip install -r packages/audio/requirements.txt. ${error instanceof Error ? error.message : error}`);
    }
    synthesized.push({ path, start: clip.start, duration: await mediaDuration(path) });
  }
  return synthesized;
}

/** Keep the rendered video unchanged and mux delayed local narration into a new MP4. */
export async function mixNarration(videoPath: string, clips: SynthesizedClip[], outputPath: string, durationSeconds: number): Promise<void> {
  if (!clips.length) return;
  const args = ["-y", "-i", videoPath];
  clips.forEach((clip) => args.push("-i", clip.path));
  const filters = clips.map((clip, index) => `[${index + 1}:a]adelay=${Math.round(clip.start * 1000)}:all=1[n${index}]`);
  filters.push(`${clips.map((_, index) => `[n${index}]`).join("")}amix=inputs=${clips.length}:duration=longest:normalize=0,apad=whole_dur=${durationSeconds}[voice]`);
  args.push("-filter_complex", filters.join(";"), "-map", "0:v:0", "-map", "[voice]", "-t", String(durationSeconds), "-c:v", "copy", "-c:a", "aac", "-movflags", "+faststart", outputPath);
  await run("ffmpeg", args, { maxBuffer: 1024 * 1024 * 4 });
}
