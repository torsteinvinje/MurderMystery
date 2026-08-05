// The murder mystery's central promise: the murderer's identity and the
// resolution NEVER reach a guest's browser before the host reveals.
//
// Until now that promise was enforced entirely by SQL nobody tested, in a
// schema that has kept changing around it (join_game was last rewritten in
// 00014). These are static assertions against the shipped migrations —
// cheap, always runnable, and they fail loudly if a future edit widens a
// player-facing payload.
//
// What this can and cannot do: it proves the SQL as written never selects the
// protected columns into a player payload. It does not execute Postgres, so it
// cannot prove runtime behaviour — that needs the integration suite against a
// real database.
import { describe, it, expect } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
// Normalise line endings before matching. Git can check these files out as
// CRLF on Windows, and the patterns below are written against \n — without
// this the same commit passes locally and fails in CI, or vice versa, for
// reasons that have nothing to do with the code. (.gitattributes now pins LF
// too; this is the belt to that pair of braces.)
const read = (p) => readFileSync(join(root, p), 'utf8').replace(/\r\n/g, '\n')

const schema = read('supabase-schema.sql')
const playerView = read('src/views/player.js')

// Pull the final definition of a function out of the generated schema (later
// definitions supersede earlier ones, so the LAST one is what runs).
function lastDefinition(name) {
  const re = new RegExp(
    String.raw`^create or replace function\s+${name}\s*\([\s\S]*?^end \$\$;`,
    'gim'
  )
  let m, last = null
  while ((m = re.exec(schema)) !== null) last = m[0]
  if (!last) throw new Error(`Function ${name} not found in supabase-schema.sql`)
  return last
}

// Every RPC a guest's browser is allowed to call, with their player_token.
const PLAYER_FACING = [
  'get_my_player',
  'get_public_suspects',
  'get_public_polaroids',
  'get_my_suspicions',
  'set_suspicion',
  'join_game',
]

describe('the murderer never leaks to a player', () => {
  it.each(PLAYER_FACING)('%s does not return is_killer or resolution', (fn) => {
    const body = lastDefinition(fn)
    // The protected columns must not appear in the JSON these build. Comments
    // are stripped first so documentation mentioning them is not a false hit.
    const sqlOnly = body.replace(/--[^\n]*/g, '')
    expect(sqlOnly, `${fn} must not expose is_killer`).not.toMatch(/is_killer/)
    expect(sqlOnly, `${fn} must not expose resolution`).not.toMatch(/resolution/)
  })

  it('get_reveal is the ONLY player-facing path to the solution, and it gates on status', () => {
    const body = lastDefinition('get_reveal')
    // It must refuse unless the host has moved the game to 'revealed'.
    expect(body).toMatch(/if v_game\.status <> 'revealed' then\s*\n\s*raise exception/)
    // Only then does it read the protected data.
    expect(body).toMatch(/where s\.game_id = v_game\.id and s\.is_killer/)
    expect(body).toMatch(/'resolution', v_game\.resolution/)
  })

  it('the public mystery catalog leaks neither the killer nor the solution', () => {
    // list_mysteries is callable by anyone, including someone who never joined.
    const body = lastDefinition('list_mysteries').replace(/--[^\n]*/g, '')
    expect(body).not.toMatch(/resolution/)
    // It may count suspects and check readiness, but must never return which
    // suspect is the killer.
    expect(body).not.toMatch(/'is_killer'/)
  })

  it('secrets and alibis of OTHER players are never returned', () => {
    // get_public_suspects is the whole-cast list every guest sees. It must
    // carry only public fields — a suspect's private `secret` belongs solely
    // to the player holding that role, via get_my_player.
    const body = lastDefinition('get_public_suspects').replace(/--[^\n]*/g, '')
    expect(body).not.toMatch(/s\.secret/)
    expect(body).not.toMatch(/s\.alibi/)
  })

  it('the player view never reads protected columns directly', () => {
    // Belt and braces: even if a future RPC regressed, the client should not
    // be reaching for these.
    const js = playerView.replace(/\/\/[^\n]*/g, '')
    expect(js).not.toMatch(/is_killer/)
    // The client may render `resolution` — but only from get_reveal's payload,
    // which the database gates. Assert it never comes from anywhere else.
    const reveals = [...js.matchAll(/resolution/g)]
    if (reveals.length > 0) {
      expect(js).toMatch(/get_reveal/)
    }
  })
})

describe('host-only data stays host-only', () => {
  it('host RPCs are the only ones returning is_killer', () => {
    // Enumerate every function that mentions is_killer in its body and assert
    // each is either host-authenticated, owner-authenticated, or get_reveal.
    const defs = [...schema.matchAll(
      /^create or replace function\s+(\w+)\s*\([\s\S]*?^end \$\$;/gim
    )]
    const leaky = []
    for (const [body, name] of defs.map((m) => [m[0], m[1]])) {
      const sqlOnly = body.replace(/--[^\n]*/g, '')
      // What matters is whether is_killer is RETURNED, not merely referenced.
      // Legitimate non-returning uses: copying rows between template and game
      // (create_game), and aggregating to a boolean (list_mysteries counts
      // killers to decide whether a mystery is playable — that count reveals
      // nothing about WHICH suspect it is).
      const returnsIt =
        /'is_killer'\s*,/.test(sqlOnly) ||      // a json_build_object key
        /\bis_killer\b(?=[^\n]*\bas\b)/i.test(sqlOnly) // aliased into a result
      if (!returnsIt) continue

      const isHost = /p_host_token/.test(body)
      const isOwner = /p_owner_token/.test(body)
      const isReveal = name === 'get_reveal'
      if (!isHost && !isOwner && !isReveal) leaky.push(name)
    }
    expect(leaky, `these expose is_killer without host/owner auth: ${leaky.join(', ')}`).toEqual([])
  })
})

describe('every migration is registered for tracking', () => {
  it('missing_migrations() knows about every up-migration on disk', () => {
    // If a migration is added without being listed in 00020, the "what have I
    // not run?" query silently under-reports — which is the exact class of
    // problem 00020 exists to end.
    const onDisk = readdirSync(join(root, 'supabase', 'migrations'))
      .filter((f) => f.endsWith('.sql') && !f.endsWith('_down.sql'))
      .map((f) => f.replace(/\.sql$/, ''))
      .sort()

    const tracking = read('supabase/migrations/00020_migration_tracking.sql')
    const known = [...tracking.matchAll(/'(\d{5}_[a-z_]+)'/g)].map((m) => m[1])

    const unlisted = onDisk.filter((v) => !known.includes(v))
    expect(unlisted, `not listed in 00020_migration_tracking.sql: ${unlisted.join(', ')}`).toEqual([])
  })
})
