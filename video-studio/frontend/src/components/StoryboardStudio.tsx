import React, { useState, useEffect } from 'react';
import {
  Layers,
  RotateCcw,
  Sparkles,
  Volume2,
  Clock,
  History,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Film,
  Eye,
  RefreshCw
} from 'lucide-react';
import { ProjectMeta, SceneItem, RenderResult } from '../types';

interface StoryboardStudioProps {
  activeProjectId?: string;
  onVideoGenerated: (result: RenderResult) => void;
}

export const StoryboardStudio: React.FC<StoryboardStudioProps> = ({
  activeProjectId,
  onVideoGenerated,
}) => {
  const [projectsList, setProjectsList] = useState<ProjectMeta[]>([]);
  const [selectedProjectId, setSelectedProjectId] = useState<string>(activeProjectId || '');
  const [projectMeta, setProjectMeta] = useState<ProjectMeta | null>(null);
  const [scenes, setScenes] = useState<SceneItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [processingSceneId, setProcessingSceneId] = useState<number | null>(null);
  const [isRenderingFull, setIsRenderingFull] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previewVideoUrl, setPreviewVideoUrl] = useState<string | null>(null);

  const stickersList = ['idea', 'question', 'brain', 'money', 'danger', 'shock', 'arrow_up', 'eye_patch'];
  const sfxList = ['whoosh', 'pop', 'ding', 'click'];
  const bgColors = ['#FEF3C7', '#EDE9FE', '#E0F2FE', '#FCE7F3', '#DCFCE7', '#F8FAFC'];

  // Cargar lista de proyectos
  const loadProjects = async () => {
    try {
      const res = await fetch('/api/projects');
      const data = await res.json();
      if (data.projects) {
        setProjectsList(data.projects);
        if (!selectedProjectId && data.projects.length > 0) {
          setSelectedProjectId(data.projects[0].id);
        }
      }
    } catch (e) {
      console.error('Error cargando proyectos', e);
    }
  };

  // Cargar datos del proyecto seleccionado
  const loadProjectDetails = async (pid: string) => {
    if (!pid) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/projects/${pid}`);
      const data = await res.json();
      if (data.success && data.data) {
        setProjectMeta(data.data.project);
        setScenes(data.data.scenes);
      } else {
        throw new Error(data.detail || 'Fallo cargando proyecto');
      }
    } catch (err: any) {
      setError(err.message || 'Error al cargar detalles del proyecto');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadProjects();
  }, []);

  useEffect(() => {
    if (activeProjectId) {
      setSelectedProjectId(activeProjectId);
    }
  }, [activeProjectId]);

  useEffect(() => {
    if (selectedProjectId) {
      loadProjectDetails(selectedProjectId);
    }
  }, [selectedProjectId]);

  // Actualizar campo de escena
  const handleUpdateScene = async (sceneId: number, field: keyof SceneItem, value: any) => {
    if (!selectedProjectId) return;
    try {
      const res = await fetch(`/api/projects/${selectedProjectId}/scenes/${sceneId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ [field]: value }),
      });
      const data = await res.json();
      if (data.success && data.data) {
        setScenes((prev) =>
          prev.map((s) => (s.id === sceneId ? { ...s, ...data.data.scene } : s))
        );
      }
    } catch (e) {
      console.error('Error actualizando escena', e);
    }
  };

  // Regenerar con IA (all, voice, visual)
  const handleRegenerate = async (sceneId: number, mode: 'all' | 'voice' | 'visual') => {
    if (!selectedProjectId) return;
    setProcessingSceneId(sceneId);
    setError(null);

    try {
      const res = await fetch(`/api/projects/${selectedProjectId}/scenes/${sceneId}/regenerate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode }),
      });
      const data = await res.json();
      if (data.success && data.data) {
        setProjectMeta(data.data.project);
        setScenes(data.data.scenes);
      } else {
        throw new Error(data.detail || 'Error en regeneración selectiva');
      }
    } catch (err: any) {
      setError(err.message || 'Error al regenerar escena con IA');
    } finally {
      setProcessingSceneId(null);
    }
  };

  // Previsualizar escena individual
  const handlePreviewScene = async (sceneId: number) => {
    if (!selectedProjectId) return;
    setProcessingSceneId(sceneId);
    setError(null);

    try {
      const res = await fetch(`/api/projects/${selectedProjectId}/scenes/${sceneId}/preview`, {
        method: 'POST',
      });
      const data = await res.json();
      if (data.success && data.result) {
        setPreviewVideoUrl(data.result.video_url);
      } else {
        throw new Error(data.detail || 'Fallo generando previsualización');
      }
    } catch (err: any) {
      setError(err.message || 'Error previsualizando escena');
    } finally {
      setProcessingSceneId(null);
    }
  };

  // Renderizar proyecto completo
  const handleRenderFullProject = async () => {
    if (!selectedProjectId) return;
    setIsRenderingFull(true);
    setError(null);

    try {
      const res = await fetch(`/api/projects/${selectedProjectId}/render`, {
        method: 'POST',
      });
      const data = await res.json();
      if (data.success && data.result) {
        onVideoGenerated(data.result);
        loadProjectDetails(selectedProjectId);
      } else {
        throw new Error(data.detail || 'Fallo al renderizar video final');
      }
    } catch (err: any) {
      setError(err.message || 'Error en renderizado final');
    } finally {
      setIsRenderingFull(false);
    }
  };

  return (
    <div className="max-w-6xl mx-auto space-y-8">
      {/* Barra de control y selector de proyectos persistidos */}
      <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex-1 w-full">
          <label className="block text-xs font-bold text-slate-400 mb-1 uppercase tracking-wider">
            Proyecto en Edición:
          </label>
          <div className="flex gap-2">
            <select
              value={selectedProjectId}
              onChange={(e) => setSelectedProjectId(e.target.value)}
              className="flex-1 bg-slate-950 border border-slate-700 rounded-xl px-4 py-2.5 text-white text-sm focus:outline-none focus:border-amber-400"
            >
              {projectsList.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.topic} ({p.scene_count} escenas • {p.target_duration_seconds}s)
                </option>
              ))}
            </select>
            <button
              onClick={() => loadProjectDetails(selectedProjectId)}
              className="bg-slate-800 hover:bg-slate-700 text-slate-300 p-2.5 rounded-xl border border-slate-700 transition"
              title="Refrescar proyecto"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        {projectMeta && (
          <div className="flex items-center gap-6 text-sm">
            <div className="bg-slate-950 border border-slate-800 px-4 py-2.5 rounded-xl">
              <div className="flex items-center gap-1.5 text-slate-400 text-xs font-bold">
                <Clock className="w-3.5 h-3.5 text-amber-400" />
                <span>Duración Real de Audio</span>
              </div>
              <p className="text-white font-black text-sm">
                {projectMeta.total_real_duration}s / {projectMeta.target_duration_seconds}s
              </p>
            </div>

            <button
              onClick={handleRenderFullProject}
              disabled={isRenderingFull}
              className="bg-amber-400 hover:bg-amber-300 disabled:opacity-50 text-slate-950 font-black px-6 py-3 rounded-2xl flex items-center gap-2 shadow-lg shadow-amber-400/20 transition active:scale-95"
            >
              {isRenderingFull ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Renderizando Todo...</span>
                </>
              ) : (
                <>
                  <Film className="w-4 h-4 fill-current" />
                  <span>Renderizar Video Completo</span>
                </>
              )}
            </button>
          </div>
        )}
      </div>

      {error && (
        <div className="flex items-center gap-3 bg-red-950/60 border border-red-500/30 text-red-300 px-5 py-4 rounded-2xl text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Modal de previsualización de escena individual */}
      {previewVideoUrl && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 max-w-md w-full shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <h4 className="font-bold text-white text-base flex items-center gap-2">
                <Eye className="w-4 h-4 text-amber-400" />
                <span>Previsualización de Escena</span>
              </h4>
              <button
                onClick={() => setPreviewVideoUrl(null)}
                className="text-slate-400 hover:text-white text-sm font-bold"
              >
                Cerrar
              </button>
            </div>
            <div className="w-[240px] h-[426px] mx-auto bg-black rounded-2xl overflow-hidden border border-slate-800 shadow-xl">
              <video src={previewVideoUrl} controls autoPlay loop className="w-full h-full object-cover" />
            </div>
          </div>
        </div>
      )}

      {/* Lista de escenas interactivas */}
      {scenes.length > 0 && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <h3 className="text-xl font-black text-white flex items-center gap-2">
              <Layers className="w-5 h-5 text-amber-400" />
              <span>Storyboard Interactivo ({scenes.length} escenas)</span>
            </h3>
            <span className="text-xs text-slate-400">
              Modifica narración, callout o regenera selectivamente con IA.
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {scenes.map((scene) => (
              <div
                key={scene.id}
                className="bg-slate-900 border border-slate-800 rounded-3xl p-6 shadow-xl relative overflow-hidden flex flex-col justify-between"
                style={{ borderTop: `6px solid ${scene.bg_color}` }}
              >
                <div className="space-y-4">
                  {/* Encabezado de la escena */}
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-black uppercase tracking-wider bg-slate-800 text-amber-400 px-3 py-1 rounded-full">
                        Escena #{scene.id} • Acto {scene.act || 1}
                      </span>
                      <span className="text-xs font-bold text-slate-400">
                        {scene.title}
                      </span>
                    </div>

                    <div className="flex items-center gap-1.5">
                      {scene.status === 'audio_ready' ? (
                        <span className="text-[10px] bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-2 py-0.5 rounded-full font-bold flex items-center gap-1">
                          <CheckCircle2 className="w-3 h-3" />
                          <span>{scene.audio_duration}s</span>
                        </span>
                      ) : (
                        <span className="text-[10px] bg-amber-500/10 text-amber-400 border border-amber-500/20 px-2 py-0.5 rounded-full font-bold">
                          Audio Pendiente
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Callout (Banner en pantalla) */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Callout en Pantalla:
                    </label>
                    <input
                      type="text"
                      value={scene.callout}
                      onChange={(e) => handleUpdateScene(scene.id, 'callout', e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-amber-300 font-black text-sm uppercase focus:outline-none focus:border-amber-400"
                    />
                  </div>

                  {/* Texto de narración */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Voz en Off (Narración):
                    </label>
                    <textarea
                      rows={3}
                      value={scene.narrative_text}
                      onChange={(e) => handleUpdateScene(scene.id, 'narrative_text', e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl p-3 text-white text-sm focus:outline-none focus:border-amber-400"
                    />
                  </div>

                  {/* Descripción Visual */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Instrucción / Prompt Visual:
                    </label>
                    <input
                      type="text"
                      value={scene.visual_description}
                      onChange={(e) => handleUpdateScene(scene.id, 'visual_description', e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-slate-300 text-xs focus:outline-none focus:border-amber-400"
                    />
                  </div>

                  {/* Reproductor de audio si ya está sintetizado */}
                  {scene.audio_url && (
                    <div className="bg-slate-950 border border-slate-800 rounded-xl p-2 flex items-center gap-2">
                      <Volume2 className="w-4 h-4 text-sky-400 flex-shrink-0" />
                      <audio src={scene.audio_url} controls className="w-full h-8" />
                    </div>
                  )}

                  {/* Parámetros visuales (Sticker, SFX, Color) */}
                  <div className="grid grid-cols-3 gap-3 pt-1">
                    <div>
                      <label className="block text-[11px] text-slate-400 mb-1">Sticker:</label>
                      <select
                        value={scene.sticker}
                        onChange={(e) => handleUpdateScene(scene.id, 'sticker', e.target.value)}
                        className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2 py-1.5 text-white text-xs"
                      >
                        {stickersList.map((stk) => (
                          <option key={stk} value={stk}>
                            {stk}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="block text-[11px] text-slate-400 mb-1">SFX:</label>
                      <select
                        value={scene.sfx}
                        onChange={(e) => handleUpdateScene(scene.id, 'sfx', e.target.value)}
                        className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2 py-1.5 text-white text-xs"
                      >
                        {sfxList.map((sfx) => (
                          <option key={sfx} value={sfx}>
                            {sfx}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="block text-[11px] text-slate-400 mb-1">Color:</label>
                      <select
                        value={scene.bg_color}
                        onChange={(e) => handleUpdateScene(scene.id, 'bg_color', e.target.value)}
                        className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2 py-1.5 text-white text-xs font-mono"
                      >
                        {bgColors.map((col) => (
                          <option key={col} value={col}>
                            {col}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>

                  {/* Historial de versiones */}
                  {scene.versions && scene.versions.length > 0 && (
                    <div className="bg-slate-950/60 border border-slate-800 rounded-xl p-2.5">
                      <div className="flex items-center gap-1.5 text-slate-400 text-[11px] font-bold mb-1">
                        <History className="w-3.5 h-3.5 text-amber-400" />
                        <span>Versiones anteriores ({scene.versions.length}):</span>
                      </div>
                      <div className="space-y-1">
                        {scene.versions.map((ver, vIdx) => (
                          <div
                            key={vIdx}
                            className="flex items-center justify-between text-[11px] text-slate-400 bg-slate-900 px-2 py-1 rounded"
                          >
                            <span className="truncate max-w-[200px]" title={ver.narrative_text}>
                              v{vIdx + 1}: {ver.narrative_text}
                            </span>
                            <button
                              onClick={() => {
                                handleUpdateScene(scene.id, 'narrative_text', ver.narrative_text);
                                handleUpdateScene(scene.id, 'callout', ver.callout);
                              }}
                              className="text-amber-400 hover:text-amber-300 font-bold ml-2"
                            >
                              Restaurar
                            </button>
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                {/* Botones de acción por escena */}
                <div className="pt-5 flex items-center justify-between border-t border-slate-800/80 mt-4 gap-2">
                  <button
                    onClick={() => handlePreviewScene(scene.id)}
                    disabled={processingSceneId === scene.id}
                    className="flex-1 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white py-2 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-1.5"
                  >
                    <Eye className="w-3.5 h-3.5 text-sky-400" />
                    <span>Previsualizar</span>
                  </button>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => handleRegenerate(scene.id, 'voice')}
                      disabled={processingSceneId === scene.id}
                      className="bg-sky-500/10 hover:bg-sky-500/20 text-sky-400 border border-sky-500/30 py-2 px-2.5 rounded-xl text-xs font-bold transition flex items-center gap-1"
                      title="Regenerar solo voz"
                    >
                      <Volume2 className="w-3.5 h-3.5" />
                      <span>Voz</span>
                    </button>

                    <button
                      onClick={() => handleRegenerate(scene.id, 'visual')}
                      disabled={processingSceneId === scene.id}
                      className="bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 border border-purple-500/30 py-2 px-2.5 rounded-xl text-xs font-bold transition flex items-center gap-1"
                      title="Regenerar solo visual"
                    >
                      <Sparkles className="w-3.5 h-3.5" />
                      <span>Visual</span>
                    </button>

                    <button
                      onClick={() => handleRegenerate(scene.id, 'all')}
                      disabled={processingSceneId === scene.id}
                      className="bg-amber-400 hover:bg-amber-300 text-slate-950 font-black py-2 px-3 rounded-xl text-xs transition flex items-center gap-1"
                      title="Regenerar escena completa con IA"
                    >
                      {processingSceneId === scene.id ? (
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      ) : (
                        <RotateCcw className="w-3.5 h-3.5" />
                      )}
                      <span>Regenerar</span>
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
