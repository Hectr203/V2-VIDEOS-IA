import React, { useState, useEffect } from 'react';
import { Sparkles, Sliders, Film, Video, Cpu } from 'lucide-react';
import { QuickGenerator } from './components/QuickGenerator';
import { StoryboardStudio } from './components/StoryboardStudio';
import { VideoGallery } from './components/VideoGallery';
import { VideoPlayerModal } from './components/VideoPlayerModal';
import { ToolsEcosystem } from './components/ToolsEcosystem';
import { VoiceProvider, RenderResult } from './types';

export const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'quick' | 'storyboard' | 'gallery' | 'tools'>('quick');
  const [voiceProviders, setVoiceProviders] = useState<VoiceProvider[]>([
    {
      provider: 'edge-tts',
      name: 'Microsoft Edge-TTS (Local/Gratis)',
      voices: [
        { id: 'es-ES-AlvaroNeural', name: 'Álvaro (España - Narrador)', gender: 'Male' },
        { id: 'es-MX-DaliaNeural', name: 'Dalia (México - Conversacional)', gender: 'Female' },
      ],
    },
  ]);
  const [activeProjectId, setActiveProjectId] = useState<string>('');
  const [currentVideo, setCurrentVideo] = useState<RenderResult | null>(null);

  useEffect(() => {
    fetch('/api/voice-catalog')
      .then((res) => res.json())
      .then((data) => {
        if (data.providers && data.providers.length > 0) {
          setVoiceProviders(data.providers);
        }
      })
      .catch((err) => console.log('Usando catálogo inicial', err));
  }, []);

  const handleProjectCreated = (projectId: string) => {
    setActiveProjectId(projectId);
    setActiveTab('storyboard');
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col justify-between selection:bg-amber-400 selection:text-slate-950">
      {/* Encabezado */}
      <header className="border-b border-slate-800 bg-slate-900/60 backdrop-blur-lg sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-2xl bg-gradient-to-tr from-amber-400 to-amber-200 flex items-center justify-center text-slate-950 shadow-lg shadow-amber-400/20">
              <Video className="w-6 h-6 stroke-[2.5]" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="font-black text-xl text-white tracking-tight">VIDEO STUDIO IA</h1>
                <span className="text-[10px] font-black uppercase tracking-wider bg-amber-400 text-slate-950 px-2 py-0.5 rounded-full">
                  Enterprise
                </span>
              </div>
              <p className="text-xs text-slate-400 font-medium">
                Orquestador Audiovisual • OmniRoute + Multi-Voice Hub + Remotion
              </p>
            </div>
          </div>

          {/* Navegación */}
          <nav className="flex items-center gap-1.5 bg-slate-950 p-1.5 rounded-2xl border border-slate-800">
            <button
              onClick={() => setActiveTab('quick')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition ${
                activeTab === 'quick'
                  ? 'bg-amber-400 text-slate-950 shadow-md shadow-amber-400/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Sparkles className="w-4 h-4" />
              <span>Orquestador IA</span>
            </button>

            <button
              onClick={() => setActiveTab('storyboard')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition ${
                activeTab === 'storyboard'
                  ? 'bg-amber-400 text-slate-950 shadow-md shadow-amber-400/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Sliders className="w-4 h-4" />
              <span>Storyboard Studio</span>
            </button>

            <button
              onClick={() => setActiveTab('gallery')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition ${
                activeTab === 'gallery'
                  ? 'bg-amber-400 text-slate-950 shadow-md shadow-amber-400/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Film className="w-4 h-4" />
              <span>Galería</span>
            </button>

            <button
              onClick={() => setActiveTab('tools')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition ${
                activeTab === 'tools'
                  ? 'bg-amber-400 text-slate-950 shadow-md shadow-amber-400/20'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Cpu className="w-4 h-4" />
              <span>Ecosistema</span>
            </button>
          </nav>
        </div>
      </header>

      {/* Cuerpo principal */}
      <main className="max-w-7xl mx-auto px-6 py-10 flex-1 w-full">
        {activeTab === 'quick' && (
          <QuickGenerator
            voiceProviders={voiceProviders}
            onProjectCreated={handleProjectCreated}
            onVideoGenerated={(video) => setCurrentVideo(video)}
          />
        )}

        {activeTab === 'storyboard' && (
          <StoryboardStudio
            activeProjectId={activeProjectId}
            onVideoGenerated={(video) => setCurrentVideo(video)}
          />
        )}

        {activeTab === 'gallery' && (
          <VideoGallery onSelectVideo={(video) => setCurrentVideo(video)} />
        )}

        {activeTab === 'tools' && <ToolsEcosystem />}
      </main>

      {/* Modal de video */}
      {currentVideo && (
        <VideoPlayerModal video={currentVideo} onClose={() => setCurrentVideo(null)} />
      )}

      {/* Footer */}
      <footer className="border-t border-slate-900 py-6 text-center text-xs text-slate-600">
        <p>Video Studio IA Enterprise • Arquitectura de producción audiovisual con IA.</p>
      </footer>
    </div>
  );
};
