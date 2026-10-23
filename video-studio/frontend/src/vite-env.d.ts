/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_VIDEO_ASSEMBLER_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
