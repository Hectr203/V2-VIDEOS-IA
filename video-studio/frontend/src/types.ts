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
  svg_prompt?: string;
  svg_markup?: string;
  source_media_id?: string | null;
  source_video_src?: string | null;
  source_start_seconds?: number;
  source_media_duration_seconds?: number | null;
  source_audio_enabled?: boolean;
  source_clip_duration_seconds?: number | null;
  sticker: string;
  sfx: string;
  bg_color: string;
  motion_type?: 'sticker' | 'manim';
  manim_clip?: string;
  audio_path?: string;
  audio_url?: string;
  audio_duration: number;
  words?: { word: string; start: number; end: number }[];
  status: 'pending_audio' | 'audio_ready' | 'source_audio_ready' | 'outdated_audio' | 'error';
  versions: SceneVersion[];
}

export interface ProjectMeta {
  id: string;
  topic: string;
  target_duration_seconds: number;
  style: string;
  voice_provider: string;
  voice_id: string;
  output_format?: 'vertical' | 'horizontal';
  visual_theme?: string;
  status: string;
  total_real_duration: number;
  scene_count: number;
  created_at: number;
  updated_at: number;
  final_video_url?: string;
  script?: { title?: string; narration?: string; duration_seconds?: number; acts?: { title: string; summary: string }[] };
  script_approved?: boolean;
  storyboard_approved?: boolean;
  storyboard_error?: string | null;
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
