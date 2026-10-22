import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// COOP/COEP: requeridos por ffmpeg.wasm multihilo (SharedArrayBuffer).
// En producción (Cloudflare Pages) los pone public/_headers.
const crossOriginIsolation = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'require-corp',
}

export default defineConfig({
  plugins: [react()],
  server: { headers: crossOriginIsolation },
  preview: { headers: crossOriginIsolation },
  optimizeDeps: { exclude: ['@ffmpeg/ffmpeg', '@ffmpeg/util'] },
})
