export interface SceneVersion {
  timestamp: number;
  narrative_text: string;
  callout: string;
  visual_description: string;
  audio_path?: string;
  audio_duration?: number;
}

export interface SceneItem {
  id: number;
  act?: number;
  title: string;
  narrative_text: string;
  visual_description: string;
  callout: string;
  visual_type: string;
  visual_asset_url?: string;
  sticker: string;
  sfx: string;
  bg_color: string;
  motion_type?: 'sticker' | 'manim';
  manim_clip?: string;
  audio_path?: string;
  audio_url?: string;
  audio_duration: number;
  words?: { word: string; start: number; end: number }[];
  status: 'pending_audio' | 'audio_ready' | 'outdated_audio' | 'error';
  versions: SceneVersion[];
}

export interface ProjectMeta {
  id: string;
  topic: string;
  target_duration_seconds: number;
  style: string;
  voice_provider: string;
  voice_id: string;
  visual_theme?: string;
  status: string;
  total_real_duration: number;
  scene_count: number;
  created_at: number;
  updated_at: number;
  final_video_url?: string;
}

export interface VoiceItem {
  id: string;
  name: string;
  gender: string;
}

export interface VoiceProvider {
  provider: string;
  name: string;
  voices: VoiceItem[];
}

export interface RenderResult {
  video_path: string;
  video_url: string;
  filename: string;
  duration_seconds: number;
  duration_frames: number;
  size_mb: number;
  render_time_seconds: number;
}

export interface VideoItem {
  filename: string;
  url: string;
  size_mb: number;
  created_at: number;
}
