import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    host: process.env.VIDEO_STUDIO_HOST || '127.0.0.1',
    port: Number(process.env.VIDEO_STUDIO_FRONTEND_PORT || 5173),
    strictPort: process.env.VIDEO_STUDIO_STRICT_PORT === '1',
    proxy: {
      '/api': {
        target: `http://127.0.0.1:${process.env.VIDEO_STUDIO_BACKEND_PORT || 8000}`,
        changeOrigin: true,
      },
      '/output': {
        target: `http://127.0.0.1:${process.env.VIDEO_STUDIO_BACKEND_PORT || 8000}`,
        changeOrigin: true,
      },
    },
  },
});
