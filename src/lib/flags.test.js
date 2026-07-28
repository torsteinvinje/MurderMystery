// Real, always-executable unit test — no database needed. Verifies the
// single most safety-critical client-side fact: the flag defaults to false,
// and only the literal string "true" turns it on.
import { describe, it, expect, afterEach, vi } from 'vitest'

describe('SABOTEUR_GAME_ENABLED', () => {
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.resetModules()
  })

  it('defaults to false when VITE_SABOTEUR_GAME_ENABLED is unset', async () => {
    vi.stubEnv('VITE_SABOTEUR_GAME_ENABLED', undefined)
    const { SABOTEUR_GAME_ENABLED } = await import('./flags.js')
    expect(SABOTEUR_GAME_ENABLED).toBe(false)
  })

  it('is false for values other than the literal string "true"', async () => {
    vi.stubEnv('VITE_SABOTEUR_GAME_ENABLED', 'yes')
    const a = await import('./flags.js')
    expect(a.SABOTEUR_GAME_ENABLED).toBe(false)

    vi.resetModules()
    vi.stubEnv('VITE_SABOTEUR_GAME_ENABLED', '1')
    const b = await import('./flags.js')
    expect(b.SABOTEUR_GAME_ENABLED).toBe(false)
  })

  it('is true only for the literal string "true"', async () => {
    vi.stubEnv('VITE_SABOTEUR_GAME_ENABLED', 'true')
    const { SABOTEUR_GAME_ENABLED } = await import('./flags.js')
    expect(SABOTEUR_GAME_ENABLED).toBe(true)
  })
})
