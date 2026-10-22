import React, { useState, useEffect } from 'react';
import { Film, Play, Download, HardDrive, RefreshCw } from 'lucide-react';
import { VideoItem, RenderResult } from '../types';

interface VideoGalleryProps {
  onSelectVideo: (video: RenderResult) => void;
}

export const VideoGallery: React.FC<VideoGalleryProps> = ({ onSelectVideo }) => {
  const [videos, setVideos] = useState<VideoItem[]>([]);
  const [loading, setLoading] = useState(false);

  const fetchVideos = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/videos');
      const data = await res.json();
      if (data.videos) {
        setVideos(data.videos);
      }
    } catch (e) {
      console.error('Error fetching videos', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchVideos();
  }, []);

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-black text-white">Galería de Videos Exportados</h2>
          <p className="text-sm text-slate-400">
            Historial de producciones guardadas en tu carpeta local <code>output/</code>.
          </p>
        </div>
        <button
          onClick={fetchVideos}
          className="bg-slate-800 hover:bg-slate-700 text-slate-300 px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 border border-slate-700 transition"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          <span>Actualizar</span>
        </button>
      </div>

      {videos.length === 0 ? (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-12 text-center">
          <Film className="w-12 h-12 text-slate-600 mx-auto mb-3" />
          <h3 className="text-lg font-bold text-slate-300">No hay videos generados aún</h3>
          <p className="text-sm text-slate-500 mt-1">
            Usa el Generador 1-Click o el Storyboard Studio para crear tu primer video.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {videos.map((vid) => (
            <div
              key={vid.filename}
              className="bg-slate-900 border border-slate-800 rounded-3xl p-5 shadow-xl flex flex-col justify-between hover:border-slate-700 transition group"
            >
              <div>
                <div className="w-full h-48 bg-slate-950 rounded-2xl border border-slate-800/80 mb-4 flex items-center justify-center relative overflow-hidden group-hover:border-amber-400/40 transition">
                  <Film className="w-10 h-10 text-slate-700 group-hover:text-amber-400/60 transition" />
                  <button
                    onClick={() =>
                      onSelectVideo({
                        filename: vid.filename,
                        video_url: vid.url,
                        video_path: vid.url,
                        duration_seconds: 0,
                        duration_frames: 0,
                        size_mb: vid.size_mb,
                        render_time_seconds: 0,
                      })
                    }
                    className="absolute inset-0 bg-slate-950/60 opacity-0 group-hover:opacity-100 flex items-center justify-center gap-2 text-white font-bold text-sm transition backdrop-blur-sm"
                  >
                    <Play className="w-5 h-5 text-amber-400 fill-current" />
                    <span>Reproducir</span>
                  </button>
                </div>

                <h4 className="font-bold text-sm text-white truncate" title={vid.filename}>
                  {vid.filename}
                </h4>

                <div className="flex items-center gap-4 text-xs text-slate-400 mt-2">
                  <span className="flex items-center gap-1">
                    <HardDrive className="w-3.5 h-3.5 text-slate-500" />
                    {vid.size_mb} MB
                  </span>
                  <span>{new Date(vid.created_at * 1000).toLocaleDateString()}</span>
                </div>
              </div>

              <div className="pt-4 flex gap-2">
                <button
                  onClick={() =>
                    onSelectVideo({
                      filename: vid.filename,
                      video_url: vid.url,
                      video_path: vid.url,
                      duration_seconds: 0,
                      duration_frames: 0,
                      size_mb: vid.size_mb,
                      render_time_seconds: 0,
                    })
                  }
                  className="flex-1 bg-slate-800 hover:bg-slate-700 text-slate-200 py-2.5 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5"
                >
                  <Play className="w-3.5 h-3.5 text-amber-400 fill-current" />
                  <span>Ver</span>
                </button>
                <a
                  href={vid.url}
                  download={vid.filename}
                  className="bg-amber-400/10 hover:bg-amber-400/20 text-amber-400 border border-amber-400/30 px-3 py-2.5 rounded-xl text-xs font-bold transition flex items-center justify-center"
                >
                  <Download className="w-3.5 h-3.5" />
                </a>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
