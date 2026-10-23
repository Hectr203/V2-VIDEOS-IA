import React from 'react'
import ReactDOM from 'react-dom/client'
import { App } from './App'
import './index.css'

// Video Studio no necesita Service Worker. Algunas vistas embebidas intentan
// registrarlo automáticamente mientras el documento aún no está activo y
// Chromium lanza InvalidStateError; no registramos uno desde la aplicación.
if ('serviceWorker' in navigator && import.meta.env.PROD) {
  navigator.serviceWorker.getRegistrations?.().then((registrations) => {
    for (const registration of registrations) {
      if (registration.scope.startsWith(window.location.origin)) {
        void registration.unregister();
      }
    }
  }).catch(() => undefined);
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
