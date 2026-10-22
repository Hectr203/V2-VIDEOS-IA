import React from 'react';
import { X, Download, Share2, Check, Film, Clock, HardDrive, Zap } from 'lucide-react';
import { RenderResult } from '../types';

interface VideoPlayerModalProps {
  video: RenderResult;
  onClose: () => void;
}

export const VideoPlayerModal: React.FC<VideoPlayerModalProps> = ({ video, onClose }) => {
  const [copied, setCopied] = React.useState(false);

  const handleCopyLink = () => {
    navigator.clipboard.writeText(window.location.origin + video.video_url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-4xl max-h-[92vh] overflow-hidden flex flex-col md:flex-row shadow-2xl relative">
        {/* Botón cerrar */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 z-10 p-2.5 rounded-full bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white transition"
        >
          <X className="w-5 h-5" />
        </button>

        {/* Reproductor Vertical 9:16 */}
        <div className="bg-black flex items-center justify-center p-6 md:w-1/2 flex-shrink-0">
          <div className="w-[270px] h-[480px] bg-slate-950 rounded-2xl overflow-hidden border-2 border-slate-800 shadow-2xl flex items-center justify-center relative">
            <video
              src={video.video_url}
              controls
              autoPlay
              playsInline
              loop
              className="w-full h-full object-cover"
            />
          </div>
        </div>

        {/* Panel lateral de información y descargas */}
        <div className="p-8 md:w-1/2 flex flex-col justify-between space-y-6 overflow-y-auto">
          <div>
            <div className="flex items-center gap-2 text-amber-400 font-bold text-xs uppercase tracking-wider mb-2">
              <Film className="w-4 h-4" />
              <span>Video Listo para Redes</span>
            </div>
            <h3 className="text-2xl font-black text-white tracking-tight break-all">
              {video.filename}
            </h3>
            <p className="text-sm text-slate-400 mt-1">
              Renderizado con subtítulos dinámicos sincronizados a 30 FPS.
            </p>

            {/* Métricas del video */}
            <div className="grid grid-cols-2 gap-3 mt-6">
              <div className="bg-slate-950 border border-slate-800 p-3.5 rounded-2xl">
                <div className="flex items-center gap-2 text-slate-400 text-xs mb-1">
                  <Clock className="w-4 h-4 text-sky-400" />
                  <span>Duración</span>
                </div>
                <p className="text-base font-black text-white">
                  {video.duration_seconds.toFixed(1)}s
                </p>
              </div>

              <div className="bg-slate-950 border border-slate-800 p-3.5 rounded-2xl">
                <div className="flex items-center gap-2 text-slate-400 text-xs mb-1">
                  <HardDrive className="w-4 h-4 text-emerald-400" />
                  <span>Tamaño MP4</span>
                </div>
                <p className="text-base font-black text-white">{video.size_mb} MB</p>
              </div>

              <div className="bg-slate-950 border border-slate-800 p-3.5 rounded-2xl">
                <div className="flex items-center gap-2 text-slate-400 text-xs mb-1">
                  <Zap className="w-4 h-4 text-amber-400" />
                  <span>Tiempo de Render</span>
                </div>
                <p className="text-base font-black text-white">
                  {video.render_time_seconds}s
                </p>
              </div>

              <div className="bg-slate-950 border border-slate-800 p-3.5 rounded-2xl">
                <div className="flex items-center gap-2 text-slate-400 text-xs mb-1">
                  <Film className="w-4 h-4 text-purple-400" />
                  <span>Resolución</span>
                </div>
                <p className="text-base font-black text-white">1080 × 1920</p>
              </div>
            </div>
          </div>

          {/* Botones de acción */}
          <div className="space-y-3 pt-4">
            <a
              href={video.video_url}
              download={video.filename}
              className="w-full bg-amber-400 hover:bg-amber-300 text-slate-950 font-black py-4 px-6 rounded-2xl flex items-center justify-center gap-2 shadow-lg shadow-amber-400/20 transition active:scale-95"
            >
              <Download className="w-5 h-5" />
              <span>Descargar MP4</span>
            </a>

            <button
              onClick={handleCopyLink}
              className="w-full bg-slate-800 hover:bg-slate-700 text-white font-bold py-3 px-6 rounded-2xl flex items-center justify-center gap-2 border border-slate-700 transition"
            >
              {copied ? (
                <>
                  <Check className="w-4 h-4 text-emerald-400" />
                  <span>¡Enlace Copiado!</span>
                </>
              ) : (
                <>
                  <Share2 className="w-4 h-4" />
                  <span>Copiar Enlace Directo</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
