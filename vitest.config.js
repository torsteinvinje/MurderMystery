import { defineConfig } from 'vitest/config'

// Deliberately separate from vite.config.js, which defines the multi-page
// app's build inputs (index/host/studio/konto.html) — irrelevant to tests
// and better kept out of the test runner's config entirely.
//
// Scope: this project had no test runner before the Skjult agenda feature.
// Vitest was added specifically and only for that feature's own logic and
// the security properties its spec calls out; it does not test the rest of
// the (untouched, pre-existing) app.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.js', 'tests/**/*.test.js'],
  },
})
