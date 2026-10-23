import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

// El editor usa Web Workers para FFmpeg, no Service Workers. Evita registros
// heredados de una versión anterior cuando se abre dentro de una vista web.
if ('serviceWorker' in navigator && import.meta.env.PROD) {
  navigator.serviceWorker.getRegistrations?.().then((registrations) => {
    for (const registration of registrations) {
      if (registration.scope.startsWith(window.location.origin)) {
        void registration.unregister();
      }
    }
  }).catch(() => undefined);
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
