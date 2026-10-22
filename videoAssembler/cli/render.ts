#!/usr/bin/env node
/**
 * Renderiza un manifiesto del Video Assembler con ffmpeg nativo.
 *
 *   node cli/render.ts manifiesto.json [--base <dir>] [--out <dir>] [--encoder videotoolbox|x264]
 *
 * --base    Carpeta raíz donde buscar los archivos del manifiesto (default: carpeta del manifiesto).
 *           Las rutas se resuelven directo contra --base; si no existen, se busca
 *           recursivamente por nombre de archivo.
 * --out     Carpeta de salida (default: carpeta actual).
 * --encoder default: videotoolbox en macOS (aceleración por hardware), x264 en otros.
 * FFMPEG / FFPROBE: variables de entorno para rutas alternativas de los binarios.
 */
import { spawn, spawnSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'
import process from 'node:process'
import type { Manifest } from '../src/lib/types.ts'
import { buildArgs, inputFiles, outputDuration, outputFileName, type Encoder } from '../src/lib/graph.ts'

const FFMPEG = process.env.FFMPEG || 'ffmpeg'
const FFPROBE = process.env.FFPROBE || 'ffprobe'

function fail(msg: string): never {
  console.error(`✖ ${msg}`)
  process.exit(1)
}

// ---- argumentos ----
const argv = process.argv.slice(2)
let manifestPath = ''
let baseDir = ''
let outDir = process.cwd()
let encoder: Encoder = process.platform === 'darwin' ? 'videotoolbox' : 'x264'

for (let i = 0; i < argv.length; i++) {
  const a = argv[i]
  if (a === '--base') baseDir = argv[++i]
  else if (a === '--out') outDir = argv[++i]
  else if (a === '--encoder') {
    const e = argv[++i]
    if (e !== 'videotoolbox' && e !== 'x264') fail(`Encoder desconocido: ${e}`)
    encoder = e
  } else if (a === '--help' || a === '-h') {
    console.log('Uso: node cli/render.ts manifiesto.json [--base <dir>] [--out <dir>] [--encoder videotoolbox|x264]')
    process.exit(0)
  } else if (!manifestPath) manifestPath = a
  else fail(`Argumento inesperado: ${a}`)
}

if (!manifestPath) fail('Falta el manifiesto. Uso: node cli/render.ts manifiesto.json [--base <dir>]')
manifestPath = resolve(manifestPath)
if (!existsSync(manifestPath)) fail(`No existe: ${manifestPath}`)
if (!baseDir) baseDir = dirname(manifestPath)
baseDir = resolve(baseDir)
outDir = resolve(outDir)

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Manifest
if (!Array.isArray(manifest.clips) || manifest.clips.length === 0) fail('El manifiesto no tiene clips')
const outputs = manifest.outputs?.length ? manifest.outputs : ['vertical' as const]

// ---- resolución de archivos ----
function findByName(dir: string, name: string, hits: string[] = []): string[] {
  for (const entry of readdirSync(dir)) {
    if (entry.startsWith('.') || entry === 'node_modules') continue
    const full = join(dir, entry)
    const st = statSync(full)
    if (st.isDirectory()) findByName(full, name, hits)
    else if (entry === name) hits.push(full)
  }
  return hits
}

function resolveFile(ref: string): string {
  const direct = resolve(baseDir, ref)
  if (existsSync(direct)) return direct
  const hits = findByName(baseDir, basename(ref))
  if (hits.length === 0) fail(`No se encontró "${ref}" bajo ${baseDir}`)
  if (hits.length > 1) console.warn(`⚠ "${basename(ref)}" aparece ${hits.length} veces; usando ${hits[0]}`)
  return hits[0]
}

const refs = inputFiles(manifest)
const inputNames = refs.map(resolveFile)
console.log('Archivos:')
for (const p of inputNames) console.log(`  ${p}`)

// ---- ¿los clips con keepAudio tienen audio? ----
function hasAudioStream(file: string): boolean {
  const r = spawnSync(FFPROBE, ['-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=index', '-of', 'csv=p=0', file], {
    encoding: 'utf8',
  })
  if (r.error || r.status !== 0) return true // sin ffprobe, asumimos que sí
  return r.stdout.trim().length > 0
}

const clipHasAudio = manifest.clips.map((c, i) => {
  if (!c.keepAudio) return true
  const ok = hasAudioStream(inputNames[i])
  if (!ok) console.warn(`⚠ ${c.file} no tiene audio; se usará silencio`)
  return ok
})

// ---- render ----
const totalDur = outputDuration(manifest)

function render(format: (typeof outputs)[number]): Promise<string> {
  const outPath = join(outDir, outputFileName(manifest, format))
  const args = buildArgs(manifest, { format, encoder, inputNames, clipHasAudio, outputName: outPath })
  args.push('-progress', 'pipe:1', '-nostats')

  return new Promise((resolvePromise, reject) => {
    console.log(`\n▶ Renderizando ${format} → ${outPath}`)
    const proc = spawn(FFMPEG, args, { stdio: ['ignore', 'pipe', 'pipe'] })
    let stderrTail = ''

    proc.stdout.setEncoding('utf8')
    proc.stdout.on('data', (chunk: string) => {
      const m = /out_time_us=(\d+)/.exec(chunk)
      if (m) {
        const pct = Math.min(100, (Number(m[1]) / 1e6 / totalDur) * 100)
        process.stdout.write(`\r  ${pct.toFixed(1)}%   `)
      }
    })
    proc.stderr.setEncoding('utf8')
    proc.stderr.on('data', (chunk: string) => {
      stderrTail = (stderrTail + chunk).slice(-4000)
    })
    proc.on('error', (err) => reject(new Error(`No se pudo ejecutar ${FFMPEG}: ${err.message}`)))
    proc.on('close', (code) => {
      process.stdout.write('\r  100.0%   \n')
      if (code === 0) resolvePromise(outPath)
      else reject(new Error(`ffmpeg falló (código ${code}):\n${stderrTail}`))
    })
  })
}

const started = Date.now()
try {
  const results: string[] = []
  for (const format of outputs) {
    results.push(await render(format))
  }
  const secs = ((Date.now() - started) / 1000).toFixed(1)
  console.log(`\n✔ Listo en ${secs}s (duración del video: ${totalDur.toFixed(1)}s)`)
  for (const r of results) console.log(`  ${r}`)
} catch (err) {
  fail(err instanceof Error ? err.message : String(err))
}
