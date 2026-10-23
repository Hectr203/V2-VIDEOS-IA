import React, { useState, useEffect } from 'react';
import {
  Film,
  Play,
  Download,
  RefreshCw,
  Plus,
  Layers,
  Clock,
  Sparkles,
  CheckCircle2,
  AlertCircle,
  Maximize2,
  X,
  Sliders,
  Ratio,
  MonitorPlay,
  Smartphone,
  Eye
} from 'lucide-react';
import { Project2D, RenderResult } from '../types';

interface ProjectDashboardProps {
  onSelectVideo: (video: RenderResult) => void;
}

export const ProjectDashboard: React.FC<ProjectDashboardProps> = ({ onSelectVideo }) => {
  const [projects, setProjects] = useState<Project2D[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  // Modales
  const [lightboxImage, setLightboxImage] = useState<{ url: string; title: string } | null>(null);
  const [renderModalProject, setRenderModalProject] = useState<Project2D | null>(null);
  const [renderAspect, setRenderAspect] = useState<'vertical' | 'horizontal' | 'both'>('vertical');
  const [renderDraft, setRenderDraft] = useState<boolean>(true);
  const [renderStills, setRenderStills] = useState<boolean>(true);
  const [rendering, setRendering] = useState<boolean>(false);
  const [renderMessage, setRenderMessage] = useState<string | null>(null);

  // Nuevo proyecto modal
  const [showNewProjectModal, setShowNewProjectModal] = useState<boolean>(false);
  const [newProjectId, setNewProjectId] = useState<string>('');
  const [newProjectTitle, setNewProjectTitle] = useState<string>('');
  const [newProjectTheme, setNewProjectTheme] = useState<string>('');
  const [creatingProject, setCreatingProject] = useState<boolean>(false);

  const fetchProjects = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/v2/projects');
      if (!res.ok) throw new Error(`HTTP error ${res.status}`);
      const data = await res.json();
      setProjects(data.projects || []);
    } catch (err: any) {
      console.error('Error cargando proyectos 2D:', err);
      setError(err.message || 'Error al conectar con la API de proyectos');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProjects();
  }, []);

  const handleCreateProject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProjectId.trim() || !newProjectTitle.trim()) return;

    setCreatingProject(true);
    try {
      const res = await fetch('/api/v2/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: newProjectId.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '-'),
          title: newProjectTitle.trim(),
          theme: newProjectTheme.trim() || undefined,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Error al crear proyecto');

      setShowNewProjectModal(false);
      setNewProjectId('');
      setNewProjectTitle('');
      setNewProjectTheme('');
      await fetchProjects();
    } catch (err: any) {
      alert(`Error creando proyecto: ${err.message}`);
    } finally {
      setCreatingProject(false);
    }
  };

  const handleTriggerRender = async () => {
    if (!renderModalProject) return;
    setRendering(true);
    setRenderMessage(null);
    try {
      const res = await fetch(`/api/v2/projects/${renderModalProject.id}/render`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          aspect: renderAspect,
          draft: renderDraft,
          stills: renderStills,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.detail || 'Error al iniciar render');

      setRenderMessage(`¡Render iniciado en segundo plano! Revisa la terminal o actualiza en unos minutos.`);
      setTimeout(() => {
        setRenderModalProject(null);
        setRenderMessage(null);
        fetchProjects();
      }, 2500);
    } catch (err: any) {
      alert(`Error iniciando render: ${err.message}`);
    } finally {
      setRendering(false);
    }
  };

  const playProjectVideo = (project: Project2D, aspect: 'vertical' | 'horizontal') => {
    const isHorizontal = aspect === 'horizontal';
    const videoUrl = isHorizontal ? project.horizontal_video_url : project.vertical_video_url;
    if (!videoUrl) return;

    const sizeMb = isHorizontal
      ? (project.master_16x9_size_mb || project.preview_16x9_size_mb || 0)
      : (project.master_size_mb || project.preview_size_mb || 0);

    onSelectVideo({
      filename: `${project.id}-${aspect}.mp4`,
      video_url: videoUrl,
      video_path: videoUrl,
      duration_seconds: project.duration_seconds,
      duration_frames: Math.round(project.duration_seconds * project.fps),
      size_mb: sizeMb,
      render_time_seconds: 0,
      is_horizontal: isHorizontal,
    });
  };

  return (
    <div className="max-w-7xl mx-auto space-y-8 pb-12">
      {/* Cabecera Principal */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800 pb-6">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-2xl font-black text-white tracking-tight">Proyectos de Animación 2D</h2>
            <span className="text-[10px] font-bold uppercase tracking-wider bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-2.5 py-0.5 rounded-full">
              Autónomos V2
            </span>
          </div>
          <p className="text-sm text-slate-400 mt-1 max-w-2xl">
            Control de producciones auto-contenidas en <code className="text-amber-400">projects/</code> con rigs vectoriales,
            contact-sheets de validación y render multiformato (9:16 Vertical y 16:9 Horizontal).
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchProjects}
            disabled={loading}
            className="bg-slate-900 hover:bg-slate-800 text-slate-300 px-4 py-2.5 rounded-2xl text-xs font-bold flex items-center gap-2 border border-slate-800 transition shadow-sm"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            <span>Actualizar</span>
          </button>
          <button
            onClick={() => setShowNewProjectModal(true)}
            className="bg-amber-400 hover:bg-amber-300 text-slate-950 px-4 py-2.5 rounded-2xl text-xs font-extrabold flex items-center gap-2 shadow-lg shadow-amber-400/20 transition"
          >
            <Plus className="w-4 h-4 stroke-[2.5]" />
            <span>Nuevo Proyecto 2D</span>
          </button>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-950/40 border border-red-800/60 rounded-2xl flex items-center gap-3 text-red-300 text-sm">
          <AlertCircle className="w-5 h-5 flex-shrink-0 text-red-400" />
          <span>{error}</span>
        </div>
      )}

      {/* Grid de Proyectos */}
      {projects.length === 0 && !loading ? (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl p-16 text-center">
          <Film className="w-12 h-12 text-slate-600 mx-auto mb-3" />
          <h3 className="text-lg font-bold text-slate-300">No hay proyectos 2D encontrados</h3>
          <p className="text-sm text-slate-500 mt-1 max-w-md mx-auto">
            Crea una nueva producción con el botón superior o ejecuta el scaffolding CLI.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {projects.map((proj) => (
            <div
              key={proj.id}
              className="bg-slate-900/90 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl hover:border-slate-700 transition flex flex-col justify-between"
            >
              <div>
                {/* Portada Visual / Contact Sheet Preview */}
                <div className="w-full h-64 bg-slate-950 relative overflow-hidden group border-b border-slate-800/80">
                  {proj.has_contact_sheet && proj.contact_sheet_url ? (
                    <img
                      src={proj.contact_sheet_url}
                      alt={`Contact sheet ${proj.title}`}
                      className="w-full h-full object-cover object-top filter brightness-95 group-hover:scale-105 transition duration-500"
                    />
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-slate-600 gap-2">
                      <Film className="w-12 h-12" />
                      <span className="text-xs font-semibold">Contact Sheet pendiente de render</span>
                    </div>
                  )}

                  <div className="absolute inset-0 bg-gradient-to-t from-slate-950 via-slate-950/40 to-transparent" />

                  {/* Badges superiores sobre imagen */}
                  <div className="absolute top-4 left-4 right-4 flex items-center justify-between">
                    <span className="bg-slate-950/80 backdrop-blur-md text-amber-400 border border-amber-400/30 text-[10px] font-black px-2.5 py-1 rounded-xl uppercase tracking-wider">
                      {proj.id}
                    </span>
                    <div className="flex items-center gap-1.5">
                      {proj.has_contact_sheet && proj.contact_sheet_url && (
                        <button
                          onClick={() => setLightboxImage({ url: proj.contact_sheet_url!, title: `${proj.title} - Contact Sheet` })}
                          className="bg-slate-900/90 hover:bg-slate-800 text-slate-200 border border-slate-700 p-2 rounded-xl text-xs flex items-center gap-1.5 backdrop-blur-md shadow-md transition"
                          title="Ver Contact Sheet en alta resolución"
                        >
                          <Maximize2 className="w-3.5 h-3.5" />
                          <span className="text-[11px] font-bold">Hoja de Contacto</span>
                        </button>
                      )}
                    </div>
                  </div>

                  {/* Métricas flotantes sobre la parte inferior de la imagen */}
                  <div className="absolute bottom-3 left-4 right-4 flex items-center justify-between text-xs font-medium text-slate-300">
                    <div className="flex items-center gap-3">
                      <span className="flex items-center gap-1 bg-slate-950/80 px-2.5 py-1 rounded-lg backdrop-blur-md">
                        <Layers className="w-3.5 h-3.5 text-amber-400" />
                        {proj.scene_count} escenas
                      </span>
                      <span className="flex items-center gap-1 bg-slate-950/80 px-2.5 py-1 rounded-lg backdrop-blur-md">
                        <Clock className="w-3.5 h-3.5 text-cyan-400" />
                        {proj.duration_seconds}s ({proj.fps} fps)
                      </span>
                    </div>
                    {proj.stills_count > 0 && (
                      <span className="text-[11px] bg-slate-950/80 px-2 py-0.5 rounded-lg text-slate-400">
                        {proj.stills_count} stills
                      </span>
                    )}
                  </div>
                </div>

                {/* Contenido descriptivo */}
                <div className="p-6 space-y-4">
                  <div>
                    <h3 className="text-xl font-black text-white tracking-tight">{proj.title}</h3>
                    <p className="text-xs text-slate-400 mt-1 line-clamp-2 leading-relaxed">
                      {proj.description || 'Sin descripción editorial.'}
                    </p>
                  </div>

                  {/* Capítulos */}
                  {proj.chapters && proj.chapters.length > 0 && (
                    <div className="flex flex-wrap gap-1.5">
                      {proj.chapters.map((chap, i) => (
                        <span
                          key={i}
                          className="text-[10px] font-semibold bg-slate-800 text-slate-300 px-2 py-0.5 rounded-md border border-slate-700/60"
                        >
                          {chap}
                        </span>
                      ))}
                    </div>
                  )}

                  {/* Estado de Variantes Multiformato */}
                  <div className="grid grid-cols-2 gap-3 pt-2">
                    {/* Vertical 9:16 */}
                    <div className={`p-3 rounded-2xl border ${proj.has_vertical ? 'bg-slate-950 border-emerald-500/30' : 'bg-slate-950/50 border-slate-800'}`}>
                      <div className="flex items-center justify-between mb-1.5">
                        <div className="flex items-center gap-1.5 text-xs font-bold text-slate-200">
                          <Smartphone className="w-3.5 h-3.5 text-emerald-400" />
                          <span>Vertical 9:16</span>
                        </div>
                        {proj.has_vertical ? (
                          <span className="w-2 h-2 rounded-full bg-emerald-400 shadow-sm shadow-emerald-400/80" />
                        ) : (
                          <span className="w-2 h-2 rounded-full bg-slate-600" />
                        )}
                      </div>
                      <div className="text-[11px] text-slate-400">
                        {proj.has_vertical ? (
                          <span>{proj.master_size_mb || proj.preview_size_mb} MB disponible</span>
                        ) : (
                          <span>Sin render</span>
                        )}
                      </div>
                    </div>

                    {/* Horizontal 16:9 */}
                    <div className={`p-3 rounded-2xl border ${proj.has_horizontal ? 'bg-slate-950 border-cyan-500/30' : 'bg-slate-950/50 border-slate-800'}`}>
                      <div className="flex items-center justify-between mb-1.5">
                        <div className="flex items-center gap-1.5 text-xs font-bold text-slate-200">
                          <MonitorPlay className="w-3.5 h-3.5 text-cyan-400" />
                          <span>Horizontal 16:9</span>
                        </div>
                        {proj.has_horizontal ? (
                          <span className="w-2 h-2 rounded-full bg-cyan-400 shadow-sm shadow-cyan-400/80" />
                        ) : (
                          <span className="w-2 h-2 rounded-full bg-slate-600" />
                        )}
                      </div>
                      <div className="text-[11px] text-slate-400">
                        {proj.has_horizontal ? (
                          <span>{proj.master_16x9_size_mb || proj.preview_16x9_size_mb} MB disponible</span>
                        ) : (
                          <span>Sin render</span>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Barra de Acciones */}
              <div className="p-6 pt-0 border-t border-slate-800/60 mt-4 flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => playProjectVideo(proj, 'vertical')}
                    disabled={!proj.has_vertical}
                    className={`px-3 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 transition ${
                      proj.has_vertical
                        ? 'bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                        : 'bg-slate-800/40 text-slate-600 border border-slate-800 cursor-not-allowed'
                    }`}
                  >
                    <Play className="w-3.5 h-3.5 fill-current" />
                    <span>Ver 9:16</span>
                  </button>

                  <button
                    onClick={() => playProjectVideo(proj, 'horizontal')}
                    disabled={!proj.has_horizontal}
                    className={`px-3 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 transition ${
                      proj.has_horizontal
                        ? 'bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-300 border border-cyan-500/30'
                        : 'bg-slate-800/40 text-slate-600 border border-slate-800 cursor-not-allowed'
                    }`}
                  >
                    <Play className="w-3.5 h-3.5 fill-current" />
                    <span>Ver 16:9</span>
                  </button>
                </div>

                <button
                  onClick={() => {
                    setRenderModalProject(proj);
                    setRenderMessage(null);
                  }}
                  className="bg-slate-800 hover:bg-slate-700 text-slate-200 px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 border border-slate-700 transition"
                >
                  <Sliders className="w-3.5 h-3.5 text-amber-400" />
                  <span>Renderizar</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Lightbox de Contact Sheet */}
      {lightboxImage && (
        <div className="fixed inset-0 z-50 bg-slate-950/90 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-5xl w-full max-h-[92vh] overflow-hidden flex flex-col shadow-2xl relative">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Eye className="w-4 h-4 text-amber-400" />
                <h4 className="text-sm font-bold text-white">{lightboxImage.title}</h4>
              </div>
              <div className="flex items-center gap-2">
                <a
                  href={lightboxImage.url}
                  download
                  target="_blank"
                  rel="noreferrer"
                  className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition"
                  title="Descargar imagen"
                >
                  <Download className="w-4 h-4" />
                </a>
                <button
                  onClick={() => setLightboxImage(null)}
                  className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white transition"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>
            <div className="flex-1 overflow-auto p-4 bg-slate-950 flex items-center justify-center">
              <img
                src={lightboxImage.url}
                alt={lightboxImage.title}
                className="max-w-full max-h-[78vh] object-contain rounded-xl shadow-lg border border-slate-800"
              />
            </div>
          </div>
        </div>
      )}

      {/* Modal de Render */}
      {renderModalProject && (
        <div className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-3xl max-w-md w-full p-6 shadow-2xl relative space-y-5">
            <button
              onClick={() => setRenderModalProject(null)}
              className="absolute top-4 right-4 p-2 rounded-full bg-slate-800 text-slate-400 hover:text-white transition"
            >
              <X className="w-4 h-4" />
            </button>

            <div>
              <div className="flex items-center gap-2 text-amber-400 font-bold text-xs uppercase tracking-wider mb-1">
                <Sliders className="w-4 h-4" />
                <span>Opciones de Exportación</span>
              </div>
              <h3 className="text-lg font-black text-white">{renderModalProject.title}</h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Configura el render para este proyecto 2D autónomo.
              </p>
            </div>

            {/* Selector de Aspecto */}
            <div className="space-y-2">
              <label className="text-xs font-bold text-slate-300">Relación de Aspecto</label>
              <div className="grid grid-cols-3 gap-2">
                <button
                  type="button"
                  onClick={() => setRenderAspect('vertical')}
                  className={`p-3 rounded-2xl text-xs font-bold border flex flex-col items-center gap-1.5 transition ${
                    renderAspect === 'vertical'
                      ? 'bg-amber-400/10 border-amber-400 text-amber-300'
                      : 'bg-slate-950 border-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  <Smartphone className="w-4 h-4" />
                  <span>9:16 Vertical</span>
                </button>
                <button
                  type="button"
                  onClick={() => setRenderAspect('horizontal')}
                  className={`p-3 rounded-2xl text-xs font-bold border flex flex-col items-center gap-1.5 transition ${
                    renderAspect === 'horizontal'
                      ? 'bg-cyan-400/10 border-cyan-400 text-cyan-300'
                      : 'bg-slate-950 border-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  <MonitorPlay className="w-4 h-4" />
                  <span>16:9 Horiz.</span>
                </button>
                <button
                  type="button"
                  onClick={() => setRenderAspect('both')}
                  className={`p-3 rounded-2xl text-xs font-bold border flex flex-col items-center gap-1.5 transition ${
                    renderAspect === 'both'
                      ? 'bg-emerald-400/10 border-emerald-400 text-emerald-300'
                      : 'bg-slate-950 border-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  <Ratio className="w-4 h-4" />
                  <span>Ambos</span>
                </button>
              </div>
            </div>

            {/* Opciones de Calidad */}
            <div className="space-y-3 pt-2">
              <label className="flex items-center gap-3 p-3 bg-slate-950 rounded-2xl border border-slate-800 cursor-pointer">
                <input
                  type="checkbox"
                  checked={renderDraft}
                  onChange={(e) => setRenderDraft(e.target.checked)}
                  className="rounded border-slate-700 text-amber-400 focus:ring-amber-400"
                />
                <div>
                  <div className="text-xs font-bold text-white">Modo Borrador Rápido (720p)</div>
                  <div className="text-[11px] text-slate-400">Renderiza en segundos para validar animación</div>
                </div>
              </label>

              <label className="flex items-center gap-3 p-3 bg-slate-950 rounded-2xl border border-slate-800 cursor-pointer">
                <input
                  type="checkbox"
                  checked={renderStills}
                  onChange={(e) => setRenderStills(e.target.checked)}
                  className="rounded border-slate-700 text-amber-400 focus:ring-amber-400"
                />
                <div>
                  <div className="text-xs font-bold text-white">Generar Stills y Contact Sheet</div>
                  <div className="text-[11px] text-slate-400">Captura un PNG por escena y compone la cuadrícula</div>
                </div>
              </label>
            </div>

            {renderMessage && (
              <div className="p-3 bg-emerald-950/40 border border-emerald-800/60 rounded-xl text-emerald-300 text-xs flex items-center gap-2">
                <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
                <span>{renderMessage}</span>
              </div>
            )}

            <div className="flex gap-3 pt-2">
              <button
                type="button"
                onClick={() => setRenderModalProject(null)}
                className="flex-1 bg-slate-800 hover:bg-slate-700 text-slate-300 py-3 rounded-2xl text-xs font-bold transition"
              >
                Cancelar
              </button>
              <button
                type="button"
                onClick={handleTriggerRender}
                disabled={rendering}
                className="flex-1 bg-amber-400 hover:bg-amber-300 text-slate-950 py-3 rounded-2xl text-xs font-extrabold flex items-center justify-center gap-2 shadow-lg shadow-amber-400/20 transition disabled:opacity-50"
              >
                {rendering ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Iniciando...</span>
                  </>
                ) : (
                  <>
                    <Play className="w-4 h-4 fill-current" />
                    <span>Comenzar Render</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal de Nuevo Proyecto 2D */}
      {showNewProjectModal && (
        <div className="fixed inset-0 z-50 bg-slate-950/85 backdrop-blur-md flex items-center justify-center p-4">
          <form
            onSubmit={handleCreateProject}
            className="bg-slate-900 border border-slate-800 rounded-3xl max-w-md w-full p-6 shadow-2xl relative space-y-4"
          >
            <button
              type="button"
              onClick={() => setShowNewProjectModal(false)}
              className="absolute top-4 right-4 p-2 rounded-full bg-slate-800 text-slate-400 hover:text-white transition"
            >
              <X className="w-4 h-4" />
            </button>

            <div>
              <div className="flex items-center gap-2 text-amber-400 font-bold text-xs uppercase tracking-wider mb-1">
                <Sparkles className="w-4 h-4" />
                <span>Nueva Producción 2D</span>
              </div>
              <h3 className="text-lg font-black text-white">Scaffolding Autónomo</h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Crea una carpeta de proyecto auto-contenida con Film.tsx, render.mjs y soporte 9:16 / 16:9.
              </p>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-bold text-slate-300">Identificador (slug)</label>
              <input
                type="text"
                value={newProjectId}
                onChange={(e) => setNewProjectId(e.target.value)}
                placeholder="ej: el-origen-del-cafe"
                required
                className="w-full bg-slate-950 border border-slate-800 rounded-2xl px-4 py-2.5 text-xs text-white focus:outline-none focus:border-amber-400 font-mono"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-bold text-slate-300">Título del Video</label>
              <input
                type="text"
                value={newProjectTitle}
                onChange={(e) => setNewProjectTitle(e.target.value)}
                placeholder="ej: El Origen Secreto del Café"
                required
                className="w-full bg-slate-950 border border-slate-800 rounded-2xl px-4 py-2.5 text-xs text-white focus:outline-none focus:border-amber-400"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-bold text-slate-300">Concepto / Tema Visual (opcional)</label>
              <textarea
                value={newProjectTheme}
                onChange={(e) => setNewProjectTheme(e.target.value)}
                placeholder="ej: Infografía de ciencia botánica, moléculas de cafeína y estilo minimalista con paleta cálida."
                rows={3}
                className="w-full bg-slate-950 border border-slate-800 rounded-2xl px-4 py-2 text-xs text-white focus:outline-none focus:border-amber-400 resize-none"
              />
            </div>

            <div className="flex gap-3 pt-3">
              <button
                type="button"
                onClick={() => setShowNewProjectModal(false)}
                className="flex-1 bg-slate-800 hover:bg-slate-700 text-slate-300 py-3 rounded-2xl text-xs font-bold transition"
              >
                Cancelar
              </button>
              <button
                type="submit"
                disabled={creatingProject || !newProjectId || !newProjectTitle}
                className="flex-1 bg-amber-400 hover:bg-amber-300 text-slate-950 py-3 rounded-2xl text-xs font-extrabold flex items-center justify-center gap-2 shadow-lg shadow-amber-400/20 transition disabled:opacity-50"
              >
                {creatingProject ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Creando...</span>
                  </>
                ) : (
                  <>
                    <Plus className="w-4 h-4 stroke-[2.5]" />
                    <span>Crear Proyecto</span>
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
};
