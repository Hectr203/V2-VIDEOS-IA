import React, { useState } from 'react';
import { Sparkles, Play, Sliders, Clock, Mic, Loader2, AlertCircle } from 'lucide-react';
import { VoiceProvider, RenderResult } from '../types';

interface QuickGeneratorProps {
  voiceProviders: VoiceProvider[];
  onProjectCreated: (projectId: string) => void;
  onVideoGenerated: (result: RenderResult) => void;
}

export const QuickGenerator: React.FC<QuickGeneratorProps> = ({
  voiceProviders,
  onProjectCreated,
  onVideoGenerated,
}) => {
  const [topic, setTopic] = useState('');
  const [targetDuration, setTargetDuration] = useState<number>(60);
  const [selectedProvider, setSelectedProvider] = useState('edge-tts');
  const [selectedVoice, setSelectedVoice] = useState('es-ES-AlvaroNeural');
  const [selectedStyle, _setSelectedStyle] = useState('curiosity');
  const [isGenerating, setIsGenerating] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [error, setError] = useState<string | null>(null);

  const durationPresets = [
    { label: '1 Min', seconds: 60 },
    { label: '3 Min', seconds: 180 },
    { label: '5 Min (Estándar)', seconds: 300 },
    { label: '10 Min (Largo)', seconds: 600 },
  ];

  const sampleTopics = [
    '¿Por qué los bostezos son contagiosos?',
    'La misteriosa paradoja de Fermi y el silencio del universo',
    'Cómo nació el primer videojuego de la historia',
    'La ingeniería detrás de los submarinos nucleares',
  ];

  const currentProviderVoices =
    voiceProviders.find((p) => p.provider === selectedProvider)?.voices || [];

  const handleCreateAndRender = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!topic.trim()) return;

    setIsGenerating(true);
    setError(null);
    setStatusMessage('1/3 Creando estructura narrativa, escenas y persistencia...');

    try {
      // 1. Crear proyecto
      const projRes = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          topic: topic.trim(),
          target_duration: targetDuration,
          style: selectedStyle,
          voice_provider: selectedProvider,
          voice_id: selectedVoice,
        }),
      });

      const projData = await projRes.json();
      if (!projData.success) throw new Error(projData.detail || 'Fallo creando proyecto');

      const projectId = projData.data.project.id;
      setStatusMessage('2/3 Sintetizando audios de escenas con sincronización karaoke...');

      // 2. Renderizar proyecto completo
      setStatusMessage('3/3 Renderizando producción en Remotion a 1080x1920...');
      const renderRes = await fetch(`/api/projects/${projectId}/render`, {
        method: 'POST',
      });
      const renderData = await renderRes.json();

      if (renderData.success && renderData.result) {
        onVideoGenerated(renderData.result);
      } else {
        throw new Error(renderData.detail || 'Fallo en renderizado');
      }
    } catch (err: any) {
      setError(err.message || 'Error en el proceso');
    } finally {
      setIsGenerating(false);
    }
  };

  const handleOnlyCreateStoryboard = async () => {
    if (!topic.trim()) return;
    setIsGenerating(true);
    setError(null);

    try {
      const projRes = await fetch('/api/projects', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          topic: topic.trim(),
          target_duration: targetDuration,
          style: selectedStyle,
          voice_provider: selectedProvider,
          voice_id: selectedVoice,
        }),
      });
      const projData = await projRes.json();
      if (projData.success) {
        onProjectCreated(projData.data.project.id);
      } else {
        throw new Error(projData.detail || 'Error al crear storyboard');
      }
    } catch (err: any) {
      setError(err.message || 'Error al crear storyboard');
    } finally {
      setIsGenerating(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto bg-slate-900 border border-slate-800 rounded-3xl p-8 shadow-2xl space-y-6">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-2xl bg-amber-400/10 border border-amber-400/20 flex items-center justify-center text-amber-400">
          <Sparkles className="w-6 h-6" />
        </div>
        <div>
          <h2 className="text-2xl font-black text-white tracking-tight">
            Orquestador de Video con IA
          </h2>
          <p className="text-slate-400 text-sm">
            Crea producciones completas de 1 a 10 minutos con guion adaptativo, múltiples motores de voz y storyboard editable.
          </p>
        </div>
      </div>

      <form onSubmit={handleCreateAndRender} className="space-y-6">
        {/* Input del tema */}
        <div>
          <label className="block text-sm font-bold text-slate-300 mb-2">
            Tema, Curiosidad o Instrucción:
          </label>
          <input
            type="text"
            value={topic}
            onChange={(e) => setTopic(e.target.value)}
            placeholder="Ej: ¿Por qué el agua caliente se congela más rápido que el agua fría?"
            disabled={isGenerating}
            className="w-full bg-slate-950 border border-slate-700 rounded-2xl px-5 py-4 text-white text-lg placeholder-slate-500 focus:outline-none focus:border-amber-400"
          />

          <div className="mt-3 flex flex-wrap gap-2 items-center">
            <span className="text-xs text-slate-500 font-medium">Sugerencias:</span>
            {sampleTopics.map((st) => (
              <button
                key={st}
                type="button"
                disabled={isGenerating}
                onClick={() => setTopic(st)}
                className="text-xs bg-slate-800 hover:bg-slate-700 text-slate-300 px-3 py-1.5 rounded-full border border-slate-700/60 transition"
              >
                {st}
              </button>
            ))}
          </div>
        </div>

        {/* Duración Configurable */}
        <div>
          <label className="block text-sm font-bold text-slate-300 mb-2 flex items-center gap-2">
            <Clock className="w-4 h-4 text-amber-400" />
            <span>Duración Objetivo del Video ({targetDuration} segundos / ~{(targetDuration / 60).toFixed(1)} min):</span>
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {durationPresets.map((preset) => (
              <button
                key={preset.seconds}
                type="button"
                disabled={isGenerating}
                onClick={() => setTargetDuration(preset.seconds)}
                className={`py-3 px-4 rounded-xl text-xs font-black transition border ${
                  targetDuration === preset.seconds
                    ? 'bg-amber-400 text-slate-950 border-amber-400 shadow-md shadow-amber-400/20'
                    : 'bg-slate-950 text-slate-300 border-slate-800 hover:border-slate-700'
                }`}
              >
                {preset.label}
              </button>
            ))}
          </div>
        </div>

        {/* Proveedor de Voz y Modelo */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-bold text-slate-300 mb-2 flex items-center gap-2">
              <Mic className="w-4 h-4 text-sky-400" />
              <span>Motor de Síntesis de Voz:</span>
            </label>
            <select
              value={selectedProvider}
              onChange={(e) => {
                setSelectedProvider(e.target.value);
                const firstVoice = voiceProviders.find((p) => p.provider === e.target.value)?.voices[0]?.id;
                if (firstVoice) setSelectedVoice(firstVoice);
              }}
              disabled={isGenerating}
              className="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-white text-sm focus:outline-none focus:border-amber-400"
            >
              {voiceProviders.map((p) => (
                <option key={p.provider} value={p.provider}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-bold text-slate-300 mb-2">
              Voz / Personaje:
            </label>
            <select
              value={selectedVoice}
              onChange={(e) => setSelectedVoice(e.target.value)}
              disabled={isGenerating}
              className="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-white text-sm focus:outline-none focus:border-amber-400"
            >
              {currentProviderVoices.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {error && (
          <div className="flex items-center gap-3 bg-red-950/60 border border-red-500/30 text-red-300 px-4 py-3 rounded-2xl text-sm">
            <AlertCircle className="w-5 h-5 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {isGenerating && (
          <div className="bg-amber-400/10 border border-amber-400/20 rounded-2xl p-4 flex items-center gap-4">
            <Loader2 className="w-6 h-6 text-amber-400 animate-spin flex-shrink-0" />
            <div>
              <p className="text-sm font-bold text-amber-300">{statusMessage}</p>
              <p className="text-xs text-amber-400/70">
                La IA está orquestando escenas, voces, stickers y montaje en Remotion...
              </p>
            </div>
          </div>
        )}

        {/* Acciones principales */}
        <div className="flex flex-col sm:flex-row items-center gap-4 pt-2">
          <button
            type="submit"
            disabled={isGenerating || !topic.trim()}
            className="w-full sm:flex-1 bg-amber-400 hover:bg-amber-300 disabled:opacity-50 text-slate-950 font-black py-4 px-6 rounded-2xl text-lg flex items-center justify-center gap-2 shadow-lg shadow-amber-400/20 transition active:scale-95"
          >
            {isGenerating ? (
              <>
                <Loader2 className="w-5 h-5 animate-spin" />
                <span>Orquestando Video...</span>
              </>
            ) : (
              <>
                <Play className="w-5 h-5 fill-current" />
                <span>Crear y Producir Video</span>
              </>
            )}
          </button>

          <button
            type="button"
            disabled={isGenerating || !topic.trim()}
            onClick={handleOnlyCreateStoryboard}
            className="w-full sm:w-auto px-6 py-4 rounded-2xl border border-slate-700 hover:border-slate-500 text-slate-300 hover:text-white font-bold text-sm transition flex items-center gap-2"
          >
            <Sliders className="w-4 h-4 text-amber-400" />
            <span>Abrir en Storyboard Studio</span>
          </button>
        </div>
      </form>
    </div>
  );
};
