// Static/textual assertions against the ACTUAL shipped SQL — not a
// re-implementation of the schema, and not a substitute for running it
// against real Postgres (see saboteur.integration.test.js for that). These
// catch the regression that matters most for a security-sensitive migration:
// someone edits or adds a function later and forgets a critical line (the
// flag check, a uniqueness constraint, a revoked grant).
//
// Always executable — no database needed.
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const read = (p) => readFileSync(join(root, p), 'utf8')

const migration = read('supabase/migrations/00011_saboteur_standalone.sql')
const migrationDown = read('supabase/migrations/00011_saboteur_standalone_down.sql')
const accountMigration = read('supabase/migrations/00012_saboteur_account.sql')
const accountMigrationDown = read('supabase/migrations/00012_saboteur_account_down.sql')
const pinsMigration = read('supabase/migrations/00013_saboteur_pins_phases.sql')
const pinsMigrationDown = read('supabase/migrations/00013_saboteur_pins_phases_down.sql')
const namesMigration = read('supabase/migrations/00014_unique_player_names.sql')
const draftsMigration = read('supabase/migrations/00015_announcement_drafts.sql')
const draftsMigrationDown = read('supabase/migrations/00015_announcement_drafts_down.sql')
const schemaFile = read('supabase-schema.sql')
const hostView = read('src/views/host.js')
const playerView = read('src/views/player.js')

describe('Skjult agenda is a STANDALONE game, not part of the murder mystery', () => {
  it('saboteur_games has its own join code and host token', () => {
    expect(migration).toMatch(/create table saboteur_games[\s\S]*?code\s+text not null unique/i)
    expect(migration).toMatch(/create table saboteur_games[\s\S]*?host_token\s+uuid not null default gen_random_uuid\(\)/i)
  })

  it('saboteur_games no longer references the murder-mystery games table', () => {
    const block = migration.match(/create table saboteur_games[\s\S]*?\n\);/i)[0]
    expect(block).not.toMatch(/references games/i)
  })

  it('participants carry their own player_token and display_name', () => {
    const block = migration.match(/create table saboteur_participants[\s\S]*?\n\);/i)[0]
    expect(block).toMatch(/player_token\s+uuid not null unique/i)
    expect(block).toMatch(/display_name\s+text not null/i)
    expect(block).not.toMatch(/references players/i)
  })

  it('has standalone entry points (create + join by code)', () => {
    expect(migration).toMatch(/create or replace function create_saboteur_game\(/i)
    expect(migration).toMatch(/create or replace function join_saboteur_game\(p_code text, p_name text\)/i)
  })

  it('host RPCs take no game id — the host_token identifies the game', () => {
    // This is what removes cross-game id tampering entirely: there is no id
    // argument left to tamper with.
    expect(migration).toMatch(/create or replace function host_get_saboteur_game\(p_host_token uuid\)/i)
    expect(migration).toMatch(/create or replace function host_open_voting_round\(p_host_token uuid\)/i)
    expect(migration).not.toMatch(/host_\w+\(p_host_token uuid, p_saboteur_game_id uuid/i)
  })

  it('player RPCs take no game id either', () => {
    expect(migration).toMatch(/create or replace function get_my_saboteur_brief\(p_player_token uuid\)/i)
    expect(migration).not.toMatch(/get_my_saboteur_brief\(p_player_token uuid, p_saboteur_game_id/i)
  })

  it('the murder-mystery views contain no Skjult agenda game logic', () => {
    // The two games must share no data, state or RPCs. A plain navigation
    // link is explicitly allowed (guests handed a Skjult agenda code will
    // otherwise try it on the main page and get a confusing error) — but
    // nothing beyond that.
    for (const [name, src] of [['host.js', hostView], ['player.js', playerView]]) {
      expect(src, `${name} must not call a saboteur RPC`).not.toMatch(/rpc\(\s*['"][a-z_]*saboteur/i)
      expect(src, `${name} must not import the saboteur view`).not.toMatch(/from\s+['"].*views\/saboteur/i)
      expect(src, `${name} must not use saboteur tokens`).not.toMatch(/SaboteurHost|SaboteurPlayer/)
    }
    // The host dashboard has no reason even to mention it.
    expect(hostView).not.toMatch(/SABOTEUR_GAME_ENABLED/)
  })

  it('never drops or alters a murder-mystery table', () => {
    for (const src of [migration, migrationDown]) {
      expect(src).not.toMatch(/drop table (if exists )?(games|players|suspects|polaroids|mysteries|profiles)\b/i)
      expect(src).not.toMatch(/alter table (games|players|suspects|polaroids|mysteries|profiles)\b/i)
    }
  })
})

describe('Skjult agenda migration — security invariants', () => {
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
      expect(migration, `${table} should enable RLS`).toMatch(
        new RegExp(`alter table ${table}\\s+enable row level security`, 'i')
      )
    }
    expect(migration).not.toMatch(/create policy/i)
  })

  it('every public RPC checks the feature flag before doing anything else', () => {
    const rpcDefs = migration.match(
      /^create or replace function (create_saboteur_game|join_saboteur_game|host_\w+|get_my_saboteur_\w+|get_saboteur_\w+|cast_saboteur_\w+|claim_saboteur_\w+)\(/gim
    ) || []
    const flagChecks = migration.match(/if not _saboteur_enabled\(\) then raise exception/g) || []
    expect(rpcDefs.length).toBeGreaterThan(0)
    expect(flagChecks.length).toBe(rpcDefs.length)
  })

  it('internal helpers have execute revoked from client roles', () => {
    const internals = [
      '_saboteur_enabled\\(\\)',
      '_saboteur_host\\(uuid\\)',
      '_saboteur_me\\(uuid\\)',
      '_saboteur_audit\\(uuid, text, jsonb\\)',
      '_saboteur_apply_transition\\(uuid, text\\)',
    ]
    for (const fn of internals) {
      expect(migration, `${fn} should have execute revoked`).toMatch(
        new RegExp(`revoke execute on function ${fn} from public, anon, authenticated`)
      )
    }
  })

  it('one ballot per voter per round is a DATABASE constraint', () => {
    expect(migration).toMatch(/unique\s*\(voting_round_id,\s*voter_participant_id\)/i)
  })

  it('objective point awards are idempotent (partial unique index)', () => {
    expect(migration).toMatch(
      /create unique index saboteur_points_ledger_idempotent[\s\S]{0,200}on saboteur_points_ledger \(source_type, source_id\) where source_id is not null/i
    )
  })

  it('hint releases are idempotent (unique per task + participant)', () => {
    expect(migration).toMatch(/unique\s*\(task_id,\s*released_to_participant_id\)/i)
  })

  it('at most one open voting round per game', () => {
    expect(migration).toMatch(
      /create unique index saboteur_voting_rounds_one_open[\s\S]{0,200}on saboteur_voting_rounds \(saboteur_game_id\) where status = 'open'/i
    )
  })

  it('"voting" is not a directly settable status', () => {
    expect(migration).toMatch(/if p_new_status = 'voting' then\s*\n\s*raise exception/)
  })

  it('starting the game requires both a Sabotør and a Lojal', () => {
    expect(migration).toMatch(/count\(distinct role\) from saboteur_participants[\s\S]{0,220}< 2 then\s*\n\s*raise exception/)
  })

  it('roles are locked once the game leaves draft', () => {
    expect(migration).toMatch(/host_set_participant_role[\s\S]*?status <> 'draft'[\s\S]*?raise exception/i)
    expect(migration).toMatch(/host_auto_assign_roles[\s\S]*?status <> 'draft'[\s\S]*?raise exception/i)
  })

  it('vote tallies are withheld until a round is BOTH closed and revealed', () => {
    expect(migration).toMatch(/'tally', case when v_round\.status = 'revealed' then/)
  })

  it('roles are revealed to players only when the game has ended', () => {
    expect(migration).toMatch(/'reveal', case when v_game\.status = 'ended' then/)
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

  it('the down-migration drops exactly the tables the up-migration creates', () => {
    // The up-migration creates app_feature_flags with "if not exists" and the
    // rest plainly; both forms must be matched.
    const created = new Set(
      (migration.match(/^create table (?:if not exists )?(\w+)/gim) || [])
        .map((s) => s.replace(/^create table (?:if not exists )?/i, ''))
    )
    const dropped = new Set(
      (migrationDown.match(/^drop table if exists (\w+)/gim) || [])
        .map((s) => s.replace(/^drop table if exists /i, ''))
    )
    expect(dropped).toEqual(created)
  })

  it('account functions require login and are scoped to the caller', () => {
    // Both must refuse when signed out, and the listing must filter on the
    // caller's own uid — it returns host_tokens, so an unscoped query would
    // hand over control of other people's games.
    expect(accountMigration).toMatch(/owner_list_saboteur_games[\s\S]*?if v_uid is null then\s*\n\s*raise exception/)
    expect(accountMigration).toMatch(/owner_claim_saboteur_game[\s\S]*?if v_uid is null then\s*\n\s*raise exception/)
    expect(accountMigration).toMatch(/from saboteur_games g\s*\n\s*where g\.owner_id = v_uid/)
    // Claiming must never steal a game already owned by a different account.
    expect(accountMigration).toMatch(/owner_id is not null and v_game\.owner_id <> v_uid[\s\S]{0,120}raise exception/)
    // Only signed-in users; never anon.
    expect(accountMigration).toMatch(/grant execute on function owner_list_saboteur_games\(\) to authenticated;/)
    expect(accountMigration).not.toMatch(/owner_list_saboteur_games\(\) to anon/)
    expect(accountMigration).not.toMatch(/owner_claim_saboteur_game\(uuid\) to anon/)
    // Flag-gated like everything else.
    expect((accountMigration.match(/if not _saboteur_enabled\(\) then raise exception/g) || []).length).toBe(2)
    // Reversible.
    expect(accountMigrationDown).toMatch(/drop function if exists owner_claim_saboteur_game\(uuid\)/)
    expect(accountMigrationDown).toMatch(/drop function if exists owner_list_saboteur_games\(\)/)
  })

  it('names are unique per game, enforced by an index (not just a check)', () => {
    // The RPC check gives the friendly message; the index is what actually
    // holds when two people submit the same name simultaneously.
    expect(pinsMigration).toMatch(
      /create unique index if not exists saboteur_participants_unique_name[\s\S]{0,160}on saboteur_participants \(saboteur_game_id, lower\(display_name\)\)/i
    )
    expect(pinsMigration).toMatch(/er allerede i bruk i dette spillet/)
    // ...and the race that slips past the check is caught and reported.
    expect(pinsMigration).toMatch(/exception when unique_violation then[\s\S]{0,160}ble akkurat tatt/)
  })

  it('every participant gets a unique 4-digit PIN', () => {
    expect(pinsMigration).toMatch(/lpad\(floor\(random\(\) \* 10000\)::int::text, 4, '0'\)/)
    expect(pinsMigration).toMatch(
      /create unique index if not exists saboteur_participants_unique_pin[\s\S]{0,160}on saboteur_participants \(saboteur_game_id, pin\)/i
    )
    expect(pinsMigration).toMatch(/alter table saboteur_participants alter column pin set not null/i)
  })

  it('rejoin returns the SAME participant and does not leak which field was wrong', () => {
    expect(pinsMigration).toMatch(/create or replace function rejoin_saboteur_game\(p_code text, p_name text, p_pin text\)/i)
    // Matches on name AND pin together, then returns that row's existing token.
    expect(pinsMigration).toMatch(/lower\(display_name\) = lower\(v_name\)\s*\n\s*and pin = v_pin/)
    expect(pinsMigration).toMatch(/Fant ingen deltaker med det navnet og den PIN-en/)
    // A guest who lost access mid-game must be able to return, so this is not
    // restricted to draft the way join_saboteur_game is.
    expect(pinsMigration).toMatch(/rejoin_saboteur_game[\s\S]*?status <> 'archived'/)
  })

  it('phase is validated server-side against a known list', () => {
    expect(pinsMigration).toMatch(/if v_phase not in \('lobby', 'roller', 'oppdrag', 'avstemning', 'avsloring'\)/)
  })

  it('announcements are host-published and reach every participant', () => {
    expect(pinsMigration).toMatch(/create table if not exists saboteur_announcements/i)
    expect(pinsMigration).toMatch(/alter table saboteur_announcements enable row level security/i)
    expect(pinsMigration).toMatch(/revoke all on saboteur_announcements from anon, authenticated/i)
    // Publishing is host-only (resolved via _saboteur_host)...
    expect(pinsMigration).toMatch(/host_publish_announcement[\s\S]{0,400}_saboteur_host\(p_host_token\)/)
    // ...and the player brief carries them for everyone, not filtered by role.
    expect(pinsMigration).toMatch(/'announcements', \(\s*\n\s*select coalesce\(json_agg/)
  })

  it('all new RPCs in 00013 are flag-gated', () => {
    const rpcDefs = pinsMigration.match(
      /^create or replace function (join_saboteur_game|rejoin_saboteur_game|host_\w+|get_my_saboteur_\w+)\(/gim
    ) || []
    const flagChecks = pinsMigration.match(/if not _saboteur_enabled\(\) then raise exception/g) || []
    expect(rpcDefs.length).toBeGreaterThan(0)
    expect(flagChecks.length).toBe(rpcDefs.length)
  })

  it('00013 is reversible', () => {
    expect(pinsMigrationDown).toMatch(/drop table if exists saboteur_announcements/i)
    expect(pinsMigrationDown).toMatch(/alter table saboteur_participants drop column if exists pin/i)
    expect(pinsMigrationDown).toMatch(/alter table saboteur_games drop column if exists phase/i)
  })

  it('murder-mystery names are unique per party too, without an index that could break existing data', () => {
    expect(namesMigration).toMatch(/er allerede i bruk på denne festen/)
    expect(namesMigration).toMatch(/lower\(display_name\) = lower\(v_name\)/)
    // Deliberately no unique index here: players is a live table that may
    // already hold duplicates from past parties, and an index would fail.
    expect(namesMigration).not.toMatch(/create unique index/i)
  })

  it('UNPUBLISHED announcement drafts are never sent to players', () => {
    // The single most important property of the draft feature: the player
    // brief must filter on `published`, or a half-written message leaks.
    const brief = draftsMigration.match(
      /create or replace function get_my_saboteur_brief[\s\S]*?\nend \$\$;/i
    )[0]
    expect(brief).toMatch(/from saboteur_announcements a\s*\n\s*where a\.saboteur_game_id = v_game\.id and a\.published/)

    // The host, by contrast, sees everything so drafts are manageable.
    const hostGet = draftsMigration.match(
      /create or replace function host_get_saboteur_game[\s\S]*?\nend \$\$;/i
    )[0]
    expect(hostGet).toMatch(/'published', a\.published/)
    expect(hostGet).not.toMatch(/where a\.saboteur_game_id = v_game\.id and a\.published/)
  })

  it('announcements have a full draft/edit/publish/retract lifecycle', () => {
    expect(draftsMigration).toMatch(/create or replace function host_upsert_announcement\(/i)
    expect(draftsMigration).toMatch(/create or replace function host_set_announcement_published\(/i)
    // Existing (pre-migration) announcements were live, so they must stay live:
    // the column is added defaulting true, then flipped to false for new rows.
    expect(draftsMigration).toMatch(/add column if not exists published boolean not null default true/i)
    expect(draftsMigration).toMatch(/alter column published set default false/i)
    // Re-publishing must not move the original publish time.
    expect(draftsMigration).toMatch(/published_at = case when v_pub then coalesce\(published_at, now\(\)\) else null end/)
    // Both new RPCs are flag-gated and host-scoped.
    expect((draftsMigration.match(/if not _saboteur_enabled\(\) then raise exception/g) || []).length).toBe(4)
    expect(draftsMigrationDown).toMatch(/drop function if exists host_upsert_announcement/i)
  })

  it('canonical supabase-schema.sql matches the standalone model', () => {
    expect(schemaFile).toMatch(/SABOTEUR_GAME_ENABLED/)
    expect(schemaFile).toMatch(/create or replace function create_saboteur_game\(/i)
    expect(schemaFile).toMatch(/create or replace function join_saboteur_game\(/i)
    // The old party-bound functions must no longer be CREATED. They may still
    // appear in `drop function if exists` cleanup lines — that is deliberate,
    // so re-running the canonical file upgrades a database that had the old
    // shape installed.
    expect(schemaFile).not.toMatch(/create or replace function get_my_saboteur_game_id/i)
    expect(schemaFile).not.toMatch(/create or replace function host_list_eligible_participants/i)
    expect(schemaFile).toMatch(/drop function if exists get_my_saboteur_game_id/i)
  })
})
