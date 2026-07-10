import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

// Three entry pages: index.html (landing + player), host.html (host view)
// and studio.html (mystery authoring).
export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        host: fileURLToPath(new URL('./host.html', import.meta.url)),
        studio: fileURLToPath(new URL('./studio.html', import.meta.url)),
      },
    },
  },
})
