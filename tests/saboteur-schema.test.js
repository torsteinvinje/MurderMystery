// Static/textual assertions against the ACTUAL shipped SQL files — not a
// re-implementation of the schema and not a substitute for running it
// against real Postgres (see saboteur.integration.test.js for that). These
// catch the class of regression that matters most for a security-sensitive
// migration: someone edits or adds a function later and forgets a
// security-critical line (the flag check, a uniqueness constraint, a
// revoked grant). Always executable — no database needed.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const read = (p) => readFileSync(join(root, p), 'utf8')

const migration = read('supabase/migrations/00009_saboteur_game.sql')
const migrationDown = read('supabase/migrations/00009_saboteur_game_down.sql')
const discovery = read('supabase/migrations/00010_saboteur_discovery.sql')
const discoveryDown = read('supabase/migrations/00010_saboteur_discovery_down.sql')
const schemaFile = read('supabase-schema.sql')

describe('Skjult agenda migration — static security invariants', () => {
  it('feature flag defaults to false', () => {
    expect(migration).toMatch(/values\s*\(\s*'SABOTEUR_GAME_ENABLED',\s*false\s*\)/i)
  })

  it('every new table gets RLS enabled, and none gets a policy (deny-all)', () => {
    const tables = [
      'app_feature_flags', 'saboteur_games', 'saboteur_participants', 'saboteur_objectives',
      'saboteur_tasks', 'saboteur_hint_releases', 'saboteur_voting_rounds', 'saboteur_ballots',
      'saboteur_points_ledger', 'saboteur_audit_log',
    ]
    for (const table of tables) {
      // The migration column-aligns these with extra spaces (matching the
      // rest of this schema's style), so whitespace must be flexible here.
      expect(migration, `${table} should enable RLS`).toMatch(
        new RegExp(`alter table ${table}\\s+enable row level security`, 'i')
      )
    }
    expect(migration).not.toMatch(/create policy/i)
  })

  it('every public RPC checks the feature flag before doing anything else', () => {
    const rpcDefs = migration.match(
      /^create or replace function (host_\w+|get_my_saboteur_\w+|get_saboteur_\w+|cast_saboteur_\w+|claim_saboteur_\w+)\(/gim
    ) || []
    const flagChecks = migration.match(/if not _saboteur_enabled\(\) then raise exception/g) || []
    expect(rpcDefs.length).toBeGreaterThan(0)
    expect(flagChecks.length).toBe(rpcDefs.length)
  })

  it('the discovery RPC (00010) also checks the feature flag', () => {
    expect(discovery).toMatch(/if not _saboteur_enabled\(\) then/)
  })

  it('internal helpers have execute revoked from client roles', () => {
    const internals = [
      '_saboteur_enabled\\(\\)',
      '_saboteur_game_for_host\\(uuid, uuid\\)',
      '_saboteur_participant_for_player\\(uuid, uuid\\)',
      '_saboteur_audit\\(uuid, text, jsonb\\)',
      '_saboteur_apply_transition\\(uuid, text\\)',
    ]
    for (const fn of internals) {
      expect(migration, `${fn} should have execute revoked`).toMatch(
        new RegExp(`revoke execute on function ${fn} from public, anon, authenticated`)
      )
    }
  })

  it('one ballot per voter per round is a DATABASE constraint, not just app logic', () => {
    expect(migration).toMatch(/unique\s*\(voting_round_id,\s*voter_participant_id\)/i)
  })

  it('objective point awards are idempotent (partial unique index)', () => {
    expect(migration).toMatch(
      /create unique index if not exists saboteur_points_ledger_idempotent[\s\S]{0,200}on saboteur_points_ledger \(source_type, source_id\) where source_id is not null/i
    )
  })

  it('hint releases are idempotent (unique per task + participant)', () => {
    expect(migration).toMatch(/unique\s*\(task_id,\s*released_to_participant_id\)/i)
  })

  it('at most one non-archived Skjult agenda per party', () => {
    expect(migration).toMatch(
      /create unique index if not exists saboteur_games_one_active_per_game[\s\S]{0,200}on saboteur_games \(game_id\) where status <> 'archived'/i
    )
  })

  it('at most one open voting round per Skjult agenda', () => {
    expect(migration).toMatch(
      /create unique index if not exists saboteur_voting_rounds_one_open[\s\S]{0,200}on saboteur_voting_rounds \(saboteur_game_id\) where status = 'open'/i
    )
  })

  it('cross-game tampering guard: both helpers re-verify ownership of the caller\'s own game_id', () => {
    expect(migration).toMatch(/_saboteur_game_for_host[\s\S]*?where id = p_saboteur_game_id and game_id = v_game\.id/)
    expect(migration).toMatch(/_saboteur_participant_for_player[\s\S]*?where id = p_saboteur_game_id and game_id = v_player\.game_id/)
  })

  it('"voting" is not a directly settable status (must go through the dedicated round RPCs)', () => {
    expect(migration).toMatch(/if p_new_status = 'voting' then\s*\n\s*raise exception/)
  })

  it('starting the game (draft -> active) requires both roles present', () => {
    expect(migration).toMatch(/count\(distinct role\) from saboteur_participants[\s\S]{0,200}< 2 then\s*\n\s*raise exception/)
  })

  it('the down-migration drops exactly the functions the up-migration creates', () => {
    const created = new Set(
      (migration.match(/^create or replace function (\w+)\(/gim) || [])
        .map((s) => s.replace(/^create or replace function /i, '').replace(/\($/, ''))
    )
    const dropped = new Set(
      (migrationDown.match(/^drop function if exists (\w+)\(/gim) || [])
        .map((s) => s.replace(/^drop function if exists /i, '').replace(/\($/, ''))
    )
    expect(dropped).toEqual(created)
  })

  it('the down-migration drops exactly the tables the up-migration creates (plus app_feature_flags)', () => {
    const created = new Set(
      (migration.match(/^create table if not exists (\w+)/gim) || [])
        .map((s) => s.replace(/^create table if not exists /i, ''))
    )
    const dropped = new Set(
      (migrationDown.match(/^drop table if exists (\w+)/gim) || [])
        .map((s) => s.replace(/^drop table if exists /i, ''))
    )
    expect(dropped).toEqual(created)
  })

  it('00010\'s down-migration drops exactly its own function', () => {
    expect(discoveryDown).toMatch(/^drop function if exists get_my_saboteur_game_id\(uuid\);$/m)
  })

  it('never drops any pre-existing table (games/players/suspects/polaroids/mysteries/profiles)', () => {
    expect(migration).not.toMatch(/drop table (games|players|suspects|polaroids|mysteries|profiles)/i)
    expect(migrationDown).not.toMatch(/drop table (games|players|suspects|polaroids|mysteries|profiles)\b/i)
  })

  it('canonical supabase-schema.sql was updated to match (contains the same flag + core tables)', () => {
    expect(schemaFile).toMatch(/SABOTEUR_GAME_ENABLED/)
    expect(schemaFile).toMatch(/create table if not exists saboteur_ballots/i)
    expect(schemaFile).toMatch(/create table if not exists saboteur_points_ledger/i)
    expect(schemaFile).toMatch(/get_my_saboteur_game_id/)
  })
})
