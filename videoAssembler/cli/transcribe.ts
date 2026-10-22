#!/usr/bin/env node
/**
 * Transcribe un audio (la nota de voz) a texto con marcas de tiempo por palabra,
 * para poder editar el video sincronizado con lo que se dice.
 *
 *   node cli/transcribe.ts voz.wav [--out transcript.json] [--lang es] [--model ruta.bin]
 *
 * Salida: JSON con el texto completo y cada palabra con su inicio/fin en segundos
 * (tiempos del ARCHIVO de audio, igual que trimIn/cuts del manifiesto).
 *
 * Requiere: whisper-cli (brew install whisper-cpp) y ffmpeg en el PATH.
 * Modelo por defecto: ~/.cache/whisper/ggml-large-v3-turbo-q5_0.bin
 *   (descarga: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin)
 */
import { spawnSync } from 'node:child_process'
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { homedir, tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import process from 'node:process'

const FFMPEG = process.env.FFMPEG || 'ffmpeg'
const WHISPER = process.env.WHISPER || 'whisper-cli'
const DEFAULT_MODEL = join(homedir(), '.cache/whisper/ggml-large-v3-turbo-q5_0.bin')

function fail(msg: string): never {
  console.error(`✖ ${msg}`)
  process.exit(1)
}

const argv = process.argv.slice(2)
let audioPath = ''
let outPath = ''
let lang = 'es'
let model = process.env.WHISPER_MODEL || DEFAULT_MODEL

for (let i = 0; i < argv.length; i++) {
  const a = argv[i]
  if (a === '--out') outPath = argv[++i]
  else if (a === '--lang') lang = argv[++i]
  else if (a === '--model') model = argv[++i]
  else if (a === '--help' || a === '-h') {
    console.log('Uso: node cli/transcribe.ts audio.wav [--out transcript.json] [--lang es] [--model ruta.bin]')
    process.exit(0)
  } else if (!audioPath) audioPath = a
  else fail(`Argumento inesperado: ${a}`)
}

if (!audioPath) fail('Falta el audio. Uso: node cli/transcribe.ts audio.wav')
audioPath = resolve(audioPath)
if (!existsSync(audioPath)) fail(`No existe: ${audioPath}`)
if (!existsSync(model)) fail(`No existe el modelo: ${model}\nDescárgalo de https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin`)
if (!outPath) outPath = `${audioPath.replace(/\.[^.]+$/, '')}.transcript.json`

const tmp = mkdtempSync(join(tmpdir(), 'transcribe-'))
try {
  // whisper necesita WAV 16 kHz mono
  const wav16 = join(tmp, 'audio16k.wav')
  const conv = spawnSync(FFMPEG, ['-v', 'error', '-y', '-i', audioPath, '-ar', '16000', '-ac', '1', '-c:a', 'pcm_s16le', wav16], {
    encoding: 'utf8',
  })
  if (conv.status !== 0) fail(`ffmpeg no pudo convertir el audio:\n${conv.stderr}`)

  const prefix = join(tmp, 'result')
  console.log('Transcribiendo… (el primer uso tarda más mientras carga el modelo)')
  const run = spawnSync(
    WHISPER,
    ['-m', model, '-f', wav16, '-l', lang, '-oj', '-of', prefix, '-ml', '1', '-sow', '-np'],
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
  )
  if (run.status !== 0) fail(`whisper-cli falló:\n${(run.stderr || '').slice(-2000)}`)

  interface WhisperSegment {
    offsets: { from: number; to: number }
    text: string
  }
  const raw = JSON.parse(readFileSync(`${prefix}.json`, 'utf8')) as { transcription: WhisperSegment[] }

  const words = raw.transcription
    .map((s) => ({
      word: s.text.trim(),
      start: Math.round(s.offsets.from) / 1000,
      end: Math.round(s.offsets.to) / 1000,
    }))
    .filter((w) => w.word.length > 0)

  const text = words.map((w) => w.word).join(' ')
  const result = { audio: audioPath, language: lang, text, words }
  writeFileSync(outPath, JSON.stringify(result, null, 2))

  const dur = words.length > 0 ? words[words.length - 1].end : 0
  console.log(`\n✔ ${words.length} palabras · ${dur.toFixed(1)}s de audio`)
  console.log(`  ${outPath}`)
  console.log(`\n${text.slice(0, 300)}${text.length > 300 ? '…' : ''}`)
} finally {
  rmSync(tmp, { recursive: true, force: true })
}
