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
  const [workflowBusy, setWorkflowBusy] = useState(false);
  const [scriptDraft, setScriptDraft] = useState('');

  const [motionLibrary, setMotionLibrary] = useState<Record<string, any[]>>({});
  const [generatingManimSceneId, setGeneratingManimSceneId] = useState<number | null>(null);

  const defaultStickers = ['idea', 'question', 'brain', 'money', 'danger', 'shock', 'arrow_up', 'eye_patch'];
  const sfxList = ['whoosh', 'pop', 'ding', 'click'];
  const bgColors = ['#FEF3C7', '#EDE9FE', '#E0F2FE', '#FCE7F3', '#DCFCE7', '#F8FAFC'];

  // Cargar biblioteca de motion/SVGs categorizados
  const loadMotionLibrary = async () => {
    try {
      const res = await fetch('/api/motion/library');
      const data = await res.json();
      if (data.categories) {
        setMotionLibrary(data.categories);
      }
    } catch (e) {
      console.error('Error cargando biblioteca de movimiento', e);
    }
  };

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
        setScriptDraft(data.data.project.script?.narration || '');
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

  const handleWorkflowAction = async (action: 'save-script' | 'approve-script' | 'approve-storyboard' | 'generate-svg') => {
    if (!selectedProjectId) return;
    setWorkflowBusy(true);
    setError(null);
    try {
      if (action === 'save-script' || action === 'approve-script') {
        const save = await fetch(`/api/projects/${selectedProjectId}/script`, {
          method: 'PUT', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ narration: scriptDraft }),
        });
        const saved = await save.json();
        if (!save.ok) throw new Error(saved.detail || 'No se pudo guardar el guion');
        if (action === 'approve-script') {
          const response = await fetch(`/api/projects/${selectedProjectId}/approve-script`, { method: 'POST' });
          const payload = await response.json();
          if (!response.ok) throw new Error(payload.detail || 'No se pudo aprobar el guion');
          setProjectMeta(payload.data.project);
          setScenes(payload.data.scenes);
          setScriptDraft(payload.data.project.script?.narration || '');
        }
      } else if (action === 'generate-svg') {
        for (const scene of scenes) {
          if (scene.svg_markup) continue;
          const result = await fetch(`/api/projects/${selectedProjectId}/scenes/${scene.id}/generate-svg`, { method: 'POST' });
          const payload = await result.json();
          if (!result.ok) throw new Error(payload.detail || `Falló el SVG de la escena ${scene.id}`);
          setScenes((current) => current.map((item) => item.id === scene.id ? { ...item, ...payload.data.scene } : item));
        }
      } else {
        const endpoint = 'approve-storyboard';
        const response = await fetch(`/api/projects/${selectedProjectId}/${endpoint}`, { method: 'POST' });
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.detail || 'No se pudo avanzar de etapa');
        setProjectMeta(payload.data.project);
        setScenes(payload.data.scenes);
        setScriptDraft(payload.data.project.script?.narration || '');
      }
      await loadProjectDetails(selectedProjectId);
    } catch (err: any) {
      setError(err.message || 'Falló el flujo de producción');
    } finally {
      setWorkflowBusy(false);
    }
  };

  useEffect(() => {
    loadProjects();
    loadMotionLibrary();
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

  // Generar escena única de Manim con IA
  const handleGenerateCustomManimScene = async (scene: SceneItem) => {
    if (!selectedProjectId) return;
    setGeneratingManimSceneId(scene.id);
    setError(null);

    try {
      const res = await fetch('/api/motion/render-custom', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          project_id: selectedProjectId,
          scene_id: scene.id,
          prompt: scene.visual_description || scene.narrative_text || scene.title,
          sticker_hint: scene.sticker ? `assets/stickers/${scene.sticker}.svg` : undefined,
        }),
      });

      const data = await res.json();
      if (data.success) {
        await loadProjectDetails(selectedProjectId);
      } else {
        throw new Error(data.detail || 'Fallo generando animación Manim');
      }
    } catch (err: any) {
      setError(err.message || 'Error generando escena Manim');
    } finally {
      setGeneratingManimSceneId(null);
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
              disabled={isRenderingFull || !projectMeta.storyboard_approved || scenes.length === 0 || scenes.some((scene) => !scene.svg_markup)}
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

      {projectMeta && (
        <section className="bg-slate-900 border border-slate-800 rounded-3xl p-6 space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h3 className="text-lg font-black text-white">Flujo de producción</h3>
              <p className="text-xs text-slate-400">Guion → aprobación → storyboard → aprobación → SVG → Remotion local</p>
            </div>
            <span className="rounded-full border border-amber-400/30 bg-amber-400/10 px-3 py-1 text-xs font-bold text-amber-300">
              {projectMeta.status}
            </span>
          </div>

          {!projectMeta.script_approved && projectMeta.script && (
            <div className="space-y-3">
              <label className="block text-sm font-bold text-slate-300" htmlFor="script-draft">Guion generado por OmniRoute (editable)</label>
              <textarea id="script-draft" rows={12} value={scriptDraft} onChange={(event) => setScriptDraft(event.target.value)}
                className="w-full rounded-2xl border border-slate-700 bg-slate-950 p-4 text-sm leading-6 text-white focus:border-amber-400 focus:outline-none" />
              <div className="flex flex-wrap gap-3">
                <button type="button" disabled={workflowBusy} onClick={() => handleWorkflowAction('save-script')} className="rounded-xl border border-slate-700 px-4 py-2 text-sm font-bold text-slate-200 disabled:opacity-50">Guardar cambios</button>
                <button type="button" disabled={workflowBusy} onClick={() => handleWorkflowAction('approve-script')} className="rounded-xl bg-amber-400 px-4 py-2 text-sm font-black text-slate-950 disabled:opacity-50">Aprobar guion y crear storyboard</button>
              </div>
            </div>
          )}

          {projectMeta.script_approved && scenes.length > 0 && !projectMeta.storyboard_approved && (
            <button type="button" disabled={workflowBusy} onClick={() => handleWorkflowAction('approve-storyboard')} className="rounded-xl bg-amber-400 px-4 py-2 text-sm font-black text-slate-950 disabled:opacity-50">
              Aprobar storyboard y permitir generación SVG
            </button>
          )}

          {projectMeta.storyboard_approved && scenes.some((scene) => !scene.svg_markup) && (
            <button type="button" disabled={workflowBusy} onClick={() => handleWorkflowAction('generate-svg')} className="rounded-xl bg-purple-500 px-4 py-2 text-sm font-black text-white disabled:opacity-50">
              {workflowBusy ? 'Generando ilustraciones SVG…' : `Generar SVG originales (${scenes.filter((scene) => !scene.svg_markup).length} pendientes)`}
            </button>
          )}
          {projectMeta.storyboard_approved && scenes.length > 0 && scenes.every((scene) => scene.svg_markup) && <p className="text-sm font-bold text-emerald-300">SVG listos. El render local con Remotion ya está habilitado.</p>}
        </section>
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

                  {/* Descripción de escena */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Descripción visual:
                    </label>
                    <input
                      type="text"
                      value={scene.visual_description}
                      onChange={(e) => handleUpdateScene(scene.id, 'visual_description', e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-slate-300 text-xs focus:outline-none focus:border-amber-400"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-400 mb-1">
                      Instrucción para el SVG original:
                    </label>
                    <textarea
                      rows={3}
                      value={scene.svg_prompt || ''}
                      onChange={(e) => handleUpdateScene(scene.id, 'svg_prompt', e.target.value)}
                      className="w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2 text-xs text-slate-200 focus:border-amber-400 focus:outline-none"
                    />
                  </div>

                  {scene.svg_markup && (
                    <div className="rounded-2xl border border-slate-800 bg-slate-950 p-3">
                      <p className="mb-2 text-xs font-bold text-emerald-300">Ilustración SVG original</p>
                      <div className="mx-auto h-64 max-w-64 overflow-hidden rounded-xl bg-slate-900 p-2" dangerouslySetInnerHTML={{ __html: scene.svg_markup }} />
                    </div>
                  )}

                  {/* Reproductor de audio si ya está sintetizado */}
                  {scene.audio_url && (
                    <div className="bg-slate-950 border border-slate-800 rounded-xl p-2 flex items-center gap-2">
                      <Volume2 className="w-4 h-4 text-sky-400 flex-shrink-0" />
                      <audio src={scene.audio_url} controls className="w-full h-8" />
                    </div>
                  )}

                  {/* Parámetros visuales (Sticker/Animación, SFX, Color) */}
                  <div className="grid grid-cols-3 gap-3 pt-1">
                    <div className="col-span-1">
                      <label className="block text-[11px] text-slate-400 mb-1">Elemento Visual:</label>
                      <select
                        value={scene.sticker}
                        onChange={(e) => handleUpdateScene(scene.id, 'sticker', e.target.value)}
                        className="w-full bg-slate-950 border border-slate-700 rounded-lg px-2 py-1.5 text-white text-xs truncate"
                      >
                        {Object.keys(motionLibrary).length > 0 ? (
                          Object.entries(motionLibrary).map(([cat, items]) => (
                            <optgroup key={cat} label={cat.toUpperCase()} className="bg-slate-900 text-amber-400 font-bold">
                              {items.map((item: any) => (
                                <option key={item.id} value={item.id} className="text-white font-normal">
                                  {item.has_motion ? '✨ ' : ''}{item.name}
                                </option>
                              ))}
                            </optgroup>
                          ))
                        ) : (
                          defaultStickers.map((stk) => (
                            <option key={stk} value={stk}>
                              {stk}
                            </option>
                          ))
                        )}
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
                      <label className="block text-[11px] text-slate-400 mb-1">Color Fondo:</label>
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

                  {/* Selector de Modo de Animación (Rebote vs Trazado Manim) */}
                  <div className="bg-slate-950/80 border border-slate-800 rounded-xl p-3 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                    <div className="flex items-center gap-2">
                      <span className="text-xs font-bold text-slate-300">Modo de Animación:</span>
                      <div className="inline-flex rounded-lg border border-slate-800 p-0.5 bg-slate-900">
                        <button
                          type="button"
                          onClick={() => {
                            handleUpdateScene(scene.id, 'motion_type', 'sticker');
                            handleUpdateScene(scene.id, 'manim_clip', null);
                          }}
                          className={`px-2.5 py-1 text-[11px] font-bold rounded-md transition-colors ${
                            !scene.motion_type || scene.motion_type === 'sticker'
                              ? 'bg-amber-400 text-slate-950'
                              : 'text-slate-400 hover:text-white'
                          }`}
                        >
                          Rebote Elástico (Sticker)
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            handleUpdateScene(scene.id, 'motion_type', 'manim');
                            handleUpdateScene(scene.id, 'manim_clip', `motion/${scene.sticker}.webm`);
                          }}
                          className={`px-2.5 py-1 text-[11px] font-bold rounded-md transition-colors ${
                            scene.motion_type === 'manim'
                              ? 'bg-purple-600 text-white shadow-sm'
                              : 'text-slate-400 hover:text-white'
                          }`}
                        >
                          Trazado Manim (Dibujo Vectorial)
                        </button>
                      </div>
                    </div>

                    <button
                      type="button"
                      disabled={generatingManimSceneId === scene.id}
                      onClick={() => handleGenerateCustomManimScene(scene)}
                      className="px-3 py-1.5 bg-indigo-600/30 hover:bg-indigo-600/50 text-indigo-300 border border-indigo-500/30 rounded-lg text-xs font-bold flex items-center gap-1.5 transition-all disabled:opacity-50"
                      title="Usa IA para generar código Manim exclusivo para esta escena"
                    >
                      {generatingManimSceneId === scene.id ? (
                        <>
                          <Loader2 className="w-3.5 h-3.5 animate-spin text-indigo-400" />
                          <span>Animando con Manim...</span>
                        </>
                      ) : (
                        <>
                          <Sparkles className="w-3.5 h-3.5 text-indigo-400" />
                          <span>Escena Única IA (Manim)</span>
                        </>
                      )}
                    </button>
                  </div>

                  {scene.manim_clip && (
                    <div className="text-[11px] bg-purple-950/40 border border-purple-800/40 text-purple-300 px-3 py-1.5 rounded-lg flex items-center justify-between">
                      <span>Clip Manim asignado: <strong className="text-white font-mono">{scene.manim_clip}</strong></span>
                      <span className="text-[10px] bg-purple-800/60 px-1.5 py-0.5 rounded font-bold uppercase">Transparente</span>
                    </div>
                  )}

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
