import React, { useEffect, useState } from 'react';
import { Cpu, CheckCircle2, Zap, Layers, Volume2, Film } from 'lucide-react';

interface ToolInfo {
  name: string;
  status: string;
  type?: string;
  path?: string;
  url?: string;
  description: string;
}

export const ToolsEcosystem: React.FC = () => {
  const [tools, setTools] = useState<Record<string, ToolInfo>>({});
  const [loading, setLoading] = useState(true);
  const statusLabels: Record<string, string> = {
    available: 'Disponible localmente', active: 'Activo', connected: 'Instalado', detected: 'Código detectado',
    not_found: 'No encontrado', configured: 'Clave configurada · conexión no verificada',
    not_configured: 'Sin clave API', integrated: 'Integrado en código',
  };
  const statusLabel = (status?: string) => statusLabels[status || ''] || 'Estado desconocido';

  useEffect(() => {
    fetch('/api/tools-status')
      .then((r) => r.json())
      .then((d) => {
        setTools(d);
        setLoading(false);
      })
      .catch((e) => {
        console.error('Error cargando tools-status', e);
        setLoading(false);
      });
  }, []);

  return (
    <div className="max-w-5xl mx-auto space-y-8">
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 rounded-2xl bg-amber-400/10 border border-amber-400/20 flex items-center justify-center text-amber-400">
          <Cpu className="w-6 h-6" />
        </div>
        <div>
          <h2 className="text-2xl font-black text-white">Ecosistema de Motores y Herramientas</h2>
          <p className="text-sm text-slate-400">
            Diagnóstico de integración, compatibilidad y análisis de conveniencia operativa para la agencia.
          </p>
        </div>
      </div>

      {loading ? (
        <div className="p-12 text-center text-slate-400">Consultando estado de motores...</div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Remotion */}
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Film className="w-5 h-5 text-amber-400" />
                <h3 className="font-bold text-white text-base">Remotion 4.x</h3>
              </div>
              <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-xs px-2.5 py-0.5 rounded-full font-bold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" />
                <span>{statusLabel(tools.remotion?.status)}</span>
              </span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed">
              Motor primario de renderizado vertical (1080x1920). Anima stickers vectoriales con física de resortes elásticos (<code>spring()</code>) y subtítulos dinámicos palabra por palabra estilo karaoke.
            </p>
            <div className="bg-slate-950 p-3 rounded-xl text-xs text-slate-300">
              <strong className="text-amber-400">¿Cuándo conviene?:</strong> Imprescindible para el estilo <em>Resultaaquee</em> (doodles, texto karaoke y motion graphics).
            </div>
          </div>

          {/* videoAssembler */}
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Layers className="w-5 h-5 text-sky-400" />
                <h3 className="font-bold text-white text-base">videoAssembler</h3>
              </div>
              <span className="bg-sky-500/10 text-sky-400 border border-sky-500/20 text-xs px-2.5 py-0.5 rounded-full font-bold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" />
                <span>{statusLabel(tools.video_assembler?.status)}</span>
              </span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed">
              Localizado en <code>{tools.video_assembler?.path || 'ruta no detectada'}</code>. Ensamblador con FFmpeg nativo y manifiesto JSON.
            </p>
            <div className="bg-slate-950 p-3 rounded-xl text-xs text-slate-300">
              <strong className="text-sky-400">¿Cuándo conviene?:</strong> Excelente para unir clips pesados pregrabados (iPhone 4K, B-roll de video real). Menos conveniente para animar texto/karaoke complejo.
            </div>
          </div>

          {/* VibeVoice */}
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Volume2 className="w-5 h-5 text-purple-400" />
                <h3 className="font-bold text-white text-base">Microsoft VibeVoice</h3>
              </div>
              <span className="bg-purple-500/10 text-purple-400 border border-purple-500/20 text-xs px-2.5 py-0.5 rounded-full font-bold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" />
                <span>{statusLabel(tools.vibevoice?.status)}</span>
              </span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed">
              {tools.vibevoice?.description || 'No se confirmó la instalación local.'} <code>{tools.vibevoice?.path || ''}</code>
            </p>
            <div className="bg-slate-950 p-3 rounded-xl text-xs text-slate-300">
              <strong className="text-purple-400">¿Cuándo conviene?:</strong> Ideal para transcripción con diarización (quién dijo qué). Para TTS rápido sin GPU, Edge-TTS es 20x más veloz y ligero.
            </div>
          </div>

          {/* OmniRoute */}
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Zap className="w-5 h-5 text-amber-400" />
                <h3 className="font-bold text-white text-base">OmniRoute AI Proxy</h3>
              </div>
              <span className="bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 text-xs px-2.5 py-0.5 rounded-full font-bold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" />
                <span>{statusLabel(tools.omniroute?.status)}</span>
              </span>
            </div>
            <p className="text-xs text-slate-400 leading-relaxed">
              Endpoint configurado: <code>{tools.omniroute?.url || 'no detectado'}</code>. La conectividad se confirma al solicitar una generación; no se reportan conexiones no verificadas.
            </p>
            <div className="bg-slate-950 p-3 rounded-xl text-xs text-slate-300">
              <strong className="text-amber-400">¿Cuándo conviene?:</strong> Imprescindible para el guion largo y la dirección de arte con IA sin preocuparse por cuotas de un único proveedor.
            </div>
          </div>

          {/* Tella & ShortGPT */}
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl space-y-4 md:col-span-2">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-white text-base">Análisis de Frameworks Externos: Tella & ShortGPT</h3>
              <span className="bg-slate-800 text-slate-400 text-xs px-3 py-1 rounded-full font-mono">
                Patrones Asimilados
              </span>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs text-slate-300">
              <div className="bg-slate-950 p-4 rounded-2xl space-y-2">
                <h4 className="font-bold text-amber-400 text-sm">Tella (chanktb/tella)</h4>
                <p className="text-slate-400 leading-relaxed">
                  Genera videos estilo caricatura. <strong>Veredicto:</strong> No conviene reemplazar Remotion con Tella (usa MoviePy que sufre fugas de memoria y no tiene subtítulos animados elásticos). Conviene adoptar sus fórmulas de prompts visuales cómicos para OmniRoute.
                </p>
              </div>

              <div className="bg-slate-950 p-4 rounded-2xl space-y-2">
                <h4 className="font-bold text-sky-400 text-sm">ShortGPT (RayVentura/ShortGPT)</h4>
                <p className="text-slate-400 leading-relaxed">
                  Pionero en automatización de Shorts/Reels con stock footage. <strong>Veredicto:</strong> Conviene asimilar su ritmo narrativo de retención agresiva (gancho de 0-3s y cortes rápidos). No conviene usar su GUI de Gradio antigua frente a nuestro Storyboard interactivo en React.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
