import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'

// Two entry pages: index.html (landing + player) and host.html (host view).
export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        host: fileURLToPath(new URL('./host.html', import.meta.url)),
      },
    },
  },
})
