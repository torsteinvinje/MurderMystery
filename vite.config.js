import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

// Entry pages: index.html (landing + player), host.html (host view),
// studio.html (mystery authoring), konto.html (host accounts / auth) and
// skjult.html (Skjult agenda — a separate standalone party game).
export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        host: fileURLToPath(new URL('./host.html', import.meta.url)),
        studio: fileURLToPath(new URL('./studio.html', import.meta.url)),
        konto: fileURLToPath(new URL('./konto.html', import.meta.url)),
        skjult: fileURLToPath(new URL('./skjult.html', import.meta.url)),
      },
    },
  },
})
