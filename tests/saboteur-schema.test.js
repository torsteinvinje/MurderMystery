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
// Normalise line endings before matching. Git can check these files out as
// CRLF on Windows, and the patterns below are written against \n — without
// this the same commit passes locally and fails in CI, or vice versa, for
// reasons that have nothing to do with the code. (.gitattributes now pins LF
// too; this is the belt to that pair of braces.)
const read = (p) => readFileSync(join(root, p), 'utf8').replace(/\r\n/g, '\n')

const migration = read('supabase/migrations/00011_saboteur_standalone.sql')
const migrationDown = read('supabase/migrations/00011_saboteur_standalone_down.sql')
const accountMigration = read('supabase/migrations/00012_saboteur_account.sql')
const accountMigrationDown = read('supabase/migrations/00012_saboteur_account_down.sql')
const pinsMigration = read('supabase/migrations/00013_saboteur_pins_phases.sql')
const pinsMigrationDown = read('supabase/migrations/00013_saboteur_pins_phases_down.sql')
const namesMigration = read('supabase/migrations/00014_unique_player_names.sql')
const draftsMigration = read('supabase/migrations/00015_announcement_drafts.sql')
const draftsMigrationDown = read('supabase/migrations/00015_announcement_drafts_down.sql')
const libraryMigration = read('supabase/migrations/00016_saboteur_intro_library.sql')
const triggerMigration = read('supabase/migrations/00017_hint_trigger.sql')
const deleteMigration = read('supabase/migrations/00018_delete_objectives_tasks.sql')
const saboteurView = read('src/views/saboteur.js')
const librariesMigration = read('supabase/migrations/00019_task_and_hint_libraries.sql')
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

  it('the objective library holds all 30 entries and is copied, not referenced', () => {
    const rows = libraryMigration.match(/^\s+\(\d+,\s+'/gm) || []
    expect(rows.length).toBe(30)
    // Adding from the library copies title+points into the game, so later
    // library edits can't rewrite an objective mid-party.
    expect(libraryMigration).toMatch(
      /insert into saboteur_objectives \(saboteur_game_id, assigned_participant_id, title, points\)\s*\n\s*values \(v_game\.id, v_target, v_lib\.title, v_lib\.points\)/
    )
    // Seeding is guarded so re-running never duplicates or overwrites.
    expect(libraryMigration).toMatch(/if exists \(select 1 from saboteur_objective_library\)\s*\n\s*then\s*\n\s*return;|if exists \(select 1 from saboteur_objective_library\) then\s*\n\s*return;/)
  })

  it('random assignment is drawn server-side, never supplied by the client', () => {
    expect(libraryMigration).toMatch(/create or replace function _saboteur_random_participant\(p_game_id uuid, p_role text\)/i)
    expect(libraryMigration).toMatch(/order by random\(\) limit 1/)
    // The helper is internal only.
    expect(libraryMigration).toMatch(/revoke execute on function _saboteur_random_participant\(uuid, text\) from public, anon, authenticated/)
    // A null target means "draw one", and only among ACTIVE members of the right role.
    expect(libraryMigration).toMatch(/v_target := _saboteur_random_participant\(v_game\.id, 'SABOTEUR'\)/)
    expect(libraryMigration).toMatch(/v_target := _saboteur_random_participant\(v_game\.id, 'LOYAL'\)/)
    expect(libraryMigration).toMatch(/where saboteur_game_id = p_game_id and role = p_role and active/)
  })

  it('the intro text lives on the game so the host can edit it', () => {
    expect(libraryMigration).toMatch(/alter table saboteur_games add column if not exists intro text not null default/i)
    expect(libraryMigration).toMatch(/create or replace function host_set_saboteur_intro\(p_host_token uuid, p_intro text\)/i)
    // It reaches both the host panel and every player's brief.
    expect(libraryMigration).toMatch(/'intro', v_game\.intro/)
  })

  it('a linked hint requires BOTH the task and its trigger objective to be approved', () => {
    // No link -> release as before; link -> only once that objective is approved.
    expect(triggerMigration).toMatch(/if v_task\.trigger_objective_id is null then\s*\n\s*v_ok := true;/)
    expect(triggerMigration).toMatch(/select \(status = 'approved'\) into v_ok\s*\n\s*from saboteur_objectives where id = v_task\.trigger_objective_id/)
    // The task must already be approved before anything is released.
    expect(triggerMigration).toMatch(/if not found or v_task\.status <> 'approved' then\s*\n\s*return 0;/)
  })

  it('order does not matter: approving the objective later still releases the hint', () => {
    // Objective approval sweeps up already-approved tasks waiting on it.
    expect(triggerMigration).toMatch(
      /select id from saboteur_tasks\s*\n\s*where saboteur_game_id = v_game\.id\s*\n\s*and trigger_objective_id = v_obj\.id\s*\n\s*and status = 'approved'/
    )
    // Release stays idempotent whichever path triggers it.
    expect(triggerMigration).toMatch(/on conflict \(task_id, released_to_participant_id\) do nothing/)
    // The old 7-arg signature is dropped so PostgREST isn't left ambiguous.
    expect(triggerMigration).toMatch(/drop function if exists host_upsert_task\(uuid, uuid, uuid, text, text, text, text\);/)
  })

  it('deleting an approved objective takes its points back', () => {
    // Otherwise the leaderboard shows points from an objective nobody can see.
    expect(deleteMigration).toMatch(
      /delete from saboteur_points_ledger\s*\n\s*where source_type = 'objective' and source_id = v_obj\.id/
    )
    // Both deletes are host-scoped and flag-gated like everything else.
    expect(deleteMigration).toMatch(/host_delete_objective[\s\S]{0,600}_saboteur_host\(p_host_token\)/)
    expect(deleteMigration).toMatch(/host_delete_task[\s\S]{0,600}_saboteur_host\(p_host_token\)/)
    expect((deleteMigration.match(/if not _saboteur_enabled\(\) then raise exception/g) || []).length).toBe(2)
    // Scoped to the caller's own game, so an id from another game is rejected.
    expect(deleteMigration).toMatch(/where id = p_objective_id and saboteur_game_id = v_game\.id/)
    expect(deleteMigration).toMatch(/where id = p_task_id and saboteur_game_id = v_game\.id/)
  })

  it('the host panel offers edit and delete for objectives and tasks', () => {
    for (const hook of [
      'data-edit-objective', 'data-delete-objective',
      'data-edit-task', 'data-delete-task',
    ]) {
      expect(saboteurView, `${hook} should exist in the host panel`).toContain(hook)
    }
    expect(saboteurView).toMatch(/host_delete_objective/)
    expect(saboteurView).toMatch(/host_delete_task/)
  })

  it('title fields suggest the library without restricting free text', () => {
    // <datalist> suggests; it never blocks a typed value.
    expect(saboteurView).toMatch(/<datalist id="objective-examples">/)
    expect(saboteurView).toMatch(/list="objective-examples"/)
  })

  it('submit buttons report progress immediately', () => {
    // An add is two round trips; without this the button looks dead.
    expect(saboteurView).toMatch(/async function hostActionPending\(/)
    expect(saboteurView).toMatch(/state\.pending = key\s*\n\s*render\(\)/)
    // And a double-click cannot fire the same action twice.
    expect(saboteurView).toMatch(/if \(state\.pending\) return/)
  })

  it('seeds 25 Lojal tasks and 10 hint cards', () => {
    const taskRows = (librariesMigration.match(/insert into saboteur_task_library[\s\S]*?;\n/)[0]
      .match(/^\s{2}\(\d+,\s+'/gm) || []).length
    const hintRows = (librariesMigration.match(/insert into saboteur_hint_library[\s\S]*?;\n/)[0]
      .match(/^\s{2}\(\d+,\s+'/gm) || []).length
    expect(taskRows).toBe(25)
    expect(hintRows).toBe(10)
    // Seeding is guarded, so re-running never duplicates.
    expect(librariesMigration).toMatch(/if exists \(select 1 from saboteur_task_library\) then\s*\n\s*return;/)
    expect(librariesMigration).toMatch(/if exists \(select 1 from saboteur_hint_library\) then\s*\n\s*return;/)
  })

  it('an empty hint field means a random card; explicit text still wins', () => {
    expect(librariesMigration).toMatch(/v_text := nullif\(trim\(coalesce\(v_task\.hint_text, ''\)\), ''\)/)
    expect(librariesMigration).toMatch(/if v_text is null then[\s\S]{0,400}order by random\(\) limit 1/)
  })

  it('random hints do not repeat: per player, or per game for all_loyal', () => {
    // One player must not be dealt the same card twice...
    expect(librariesMigration).toMatch(
      /where hr\.released_to_participant_id = v_task\.assigned_participant_id\s*\n\s*and hr\.library_hint_id = l\.id/
    )
    // ...and an all_loyal deal gives ONE shared card, not a different one each,
    // so nobody reads meaning into the difference.
    expect(librariesMigration).toMatch(/where t2\.saboteur_game_id = v_task\.saboteur_game_id\s*\n\s*and hr\.library_hint_id = l\.id/)
    expect(librariesMigration).toMatch(/select v_task\.id, sp\.id, v_text, v_lib_id/)
  })

  it('the released hint text is stored on the release, not re-derived', () => {
    // A random card exists nowhere on the task, so the release has to carry it
    // — which also keeps history correct if the library is edited later.
    expect(librariesMigration).toMatch(/alter table saboteur_hint_releases add column if not exists hint_text text/i)
    expect(librariesMigration).toMatch(/'hint_text', coalesce\(nullif\(hr\.hint_text, ''\), t\.hint_text\)/)
    // Existing releases are backfilled so every row behaves the same.
    expect(librariesMigration).toMatch(/update saboteur_hint_releases hr\s*\n\s*set hint_text = t\.hint_text/)
  })

  it('hint cards are host-only; task titles are not', () => {
    // Players are meant to earn the hints, not read the deck.
    expect(librariesMigration).toMatch(/create or replace function host_list_saboteur_hint_library\(p_host_token uuid\)/i)
    expect(librariesMigration).toMatch(/host_list_saboteur_hint_library[\s\S]{0,400}_saboteur_host\(p_host_token\)/)
    expect(saboteurView).toMatch(/host_list_saboteur_hint_library[\s\S]{0,200}hostToken\(\)/)
  })

  it('every participant can vote, not just the Lojale', () => {
    const votes = read('supabase/migrations/00021_everyone_votes.sql')
    // A Sabotør who could not vote would out themselves instantly — and other
    // players could deduce roles from who had not voted.
    expect(votes).toMatch(/'can_vote', v_round\.id is not null and v_part\.active and not v_voted/)
    expect(votes).toMatch(/if not v_part\.active then\s*\n\s*raise exception/)
    // The role check must be gone from all three vote paths.
    const voteFns = votes.match(
      /create or replace function (get_my_saboteur_vote_status|get_saboteur_ballot_targets|cast_saboteur_ballot)[\s\S]*?\nend \$\$;/g
    ) || []
    expect(voteFns.length).toBe(3)
    for (const fn of voteFns) {
      expect(fn).not.toMatch(/role <> 'LOYAL'/)
      expect(fn).not.toMatch(/v_part\.role = 'LOYAL'/)
    }
    // Everything that made voting trustworthy still holds.
    expect(votes).toMatch(/status = 'open'/)              // only while open
    expect(votes).toMatch(/exception when unique_violation/) // one ballot each
  })

  it('the player screen can be shown to others without revealing the role', () => {
    // The whole point: role, missions and hints are all behind collapsed
    // controls, and the visible label must not differ by role.
    expect(saboteurView).toMatch(/<summary>[\s\S]{0,120}Din rolle — trykk for å se den<\/summary>/)
    expect(saboteurView).toMatch(/Dine oppdrag\$\{missionCount/)
    // A Sabotør-only heading would give the game away to anyone glancing over.
    expect(saboteurView).not.toMatch(/<h2>\$\{icon\(I\.objective[^}]*\}Dine mål<\/h2>/)
    expect(saboteurView).not.toMatch(/<h2>\$\{icon\(I\.task[^}]*\}Dine oppgaver<\/h2>/)
  })

  it('unpublished missions are never sent to players, and cannot be claimed', () => {
    const pub = read('supabase/migrations/00022_publish_missions.sql')
    // The player brief must filter both lists on published.
    const brief = pub.match(/create or replace function get_my_saboteur_brief[\s\S]*?\nend \$\$;/i)[0]
    expect(brief).toMatch(/from saboteur_objectives o\s*\n\s*where o\.assigned_participant_id = v_part\.id and o\.published/)
    expect(brief).toMatch(/from saboteur_tasks t\s*\n\s*where t\.assigned_participant_id = v_part\.id and t\.published/)
    // Defence in depth: a guessed or stale id cannot claim a draft either.
    expect(pub).toMatch(/where id = p_objective_id and assigned_participant_id = v_part\.id and published/)
    expect(pub).toMatch(/where id = p_task_id and assigned_participant_id = v_part\.id and published/)
    // Existing rows were live, so the column is added defaulting TRUE and only
    // then flipped to FALSE for new rows — nothing vanishes mid-game.
    for (const table of ['saboteur_objectives', 'saboteur_tasks']) {
      expect(pub).toMatch(new RegExp(`alter table ${table} add column if not exists published boolean not null default true`, 'i'))
      expect(pub).toMatch(new RegExp(`alter table ${table} alter column published set default false`, 'i'))
    }
    // Re-publishing must not move the original publish time.
    expect(pub).toMatch(/published_at = case when v_pub then coalesce\(published_at, now\(\)\) else null end/)
    // The host still sees both, or drafts would be unmanageable.
    const hostGet = pub.match(/create or replace function host_get_saboteur_game[\s\S]*?\nend \$\$;/i)[0]
    expect(hostGet).toMatch(/'published', o\.published/)
    expect(hostGet).toMatch(/'published', t\.published/)
  })

  it('the scoring loop pays out from every source, exactly once', () => {
    const sc = read('supabase/migrations/00023_scoring_loop.sql')

    // Every way to earn a point is a recognised source_type.
    expect(sc).toMatch(/check \(source_type in \('objective', 'task', 'correct_vote', 'undetected', 'adjustment'\)\)/)

    // Correct votes only pay LOYAL voters who picked an actual Sabotør, and
    // the ledger's partial unique index is what stops a double payout.
    const reveal = sc.match(/create or replace function host_reveal_voting_round[\s\S]*?\nend \$\$;/i)[0]
    expect(reveal).toMatch(/voter\.role = 'LOYAL'/)
    expect(reveal).toMatch(/target\.role = 'SABOTEUR'/)
    expect(reveal).toMatch(/on conflict \(source_type, source_id\)[\s\S]{0,60}do nothing/)

    // The undetected bonus shrinks with every vote received, and never goes
    // negative — a Sabotør everyone voted for still scores 0, not minus.
    expect(sc).toMatch(/greatest\(0, 5 - /)

    // Host bonuses are the one source that may repeat, so they carry a null
    // source_id (the unique index only covers non-null ones) and are capped.
    const bonus = sc.match(/create or replace function host_award_bonus[\s\S]*?\nend \$\$;/i)[0]
    expect(bonus).toMatch(/'adjustment', null/)
    expect(bonus).toMatch(/abs\(p_points\) > 50/)
  })

  it('voting cannot open while sabotørmål are still unsettled', () => {
    const sc = read('supabase/migrations/00023_scoring_loop.sql')
    const open = sc.match(/create or replace function host_open_voting_round[\s\S]*?\nend \$\$;/i)[0]
    // Published-but-undecided objectives block the round: the whole point is
    // that the evidence is in before anyone points a finger.
    expect(open).toMatch(/published and status in \('assigned', 'claimed'\)/)
    expect(open).toMatch(/if v_unsettled > 0 then/)
    // And the host-chosen round limit is enforced server-side, not just in UI.
    expect(open).toMatch(/max_voting_rounds/)
    expect(sc).toMatch(/create or replace function host_set_max_voting_rounds/i)
    expect(sc).toMatch(/saboteur_games_max_rounds_check[\s\S]{0,120}between 1 and 3/)
  })

  it('vote reasons stay hidden until the round is revealed', () => {
    const sc = read('supabase/migrations/00023_scoring_loop.sql')
    const hostGet = sc.match(/create or replace function host_get_saboteur_game[\s\S]*?\nend \$\$;/i)[0]
    // Reading someone's reason early would expose who suspects whom.
    expect(hostGet).toMatch(/'reasons', case when v_round\.status = 'revealed' then/)
    // And a player's own screen only ever counts votes against them, and only
    // from rounds already revealed.
    const brief = sc.match(/create or replace function get_my_saboteur_brief[\s\S]*?\nend \$\$;/i)[0]
    expect(brief).toMatch(/votes_against_me/)
    expect(brief).toMatch(/r\.status = 'revealed'/)
    // The brief must never hand a player anyone else's role before the end.
    const beforeReveal = brief.slice(0, brief.indexOf("'reveal'"))
    expect(beforeReveal).not.toMatch(/'role', /)
  })

  it('every migration is registered so missing_migrations() can spot it', () => {
    const known = read('supabase/migrations/00020_migration_tracking.sql')
    expect(known).toMatch(/'00023_scoring_loop'/)
    // The down-migration must undo the new signatures, or a rollback leaves
    // two ambiguous overloads behind.
    const down = read('supabase/migrations/00023_scoring_loop_down.sql')
    expect(down).toMatch(/drop function if exists cast_saboteur_ballot\(uuid, uuid, uuid, text\)/)
    expect(down).toMatch(/drop function if exists host_upsert_task\(uuid, uuid, uuid, text, text, text, text, uuid, int\)/)
  })

  it('planned objectives belong to nobody, so they cannot reach a player', () => {
    const plan = read('supabase/migrations/00024_plan_ahead.sql')

    // A bundle row has no owner at all. Every player-facing query filters on
    // "assigned_participant_id = my id", so an unowned row is invisible by
    // construction rather than by a rule someone has to remember.
    expect(plan).toMatch(/alter column assigned_participant_id drop not null/)
    expect(plan).toMatch(/planned_slot is null or planned_slot between 1 and 3/)
    // But it must never be BOTH unowned and unbundled - that row would be
    // invisible to the host too, and quietly lost.
    expect(plan).toMatch(/check \(assigned_participant_id is not null or planned_slot is not null\)/)

    // The player brief still filters on ownership (unchanged by this file, so
    // assert it against the canonical schema's final state).
    expect(schemaFile).toMatch(/where o\.assigned_participant_id = v_part\.id and o\.published/)

    // Bundles are a draft-time tool; once the game runs, objectives go to
    // real people.
    expect(plan).toMatch(/Bunker kan bare settes opp mens spillet er i utkast/)
  })

  it('reshuffling roles pulls undealt objectives back out of play', () => {
    const plan = read('supabase/migrations/00024_plan_ahead.sql')
    const undeal = plan.match(/create or replace function _saboteur_undeal_planned[\s\S]*?\nend \$\$;/i)[0]

    // The dangerous case: game goes back to draft, roles are redealt, and a
    // Sabotor objective is left sitting with someone who is now Lojal.
    expect(undeal).toMatch(/set assigned_participant_id = null/)
    expect(undeal).toMatch(/planned_slot is not null/)
    // Anything already claimed or decided is history and stays put.
    expect(undeal).toMatch(/status = 'assigned'/)

    // And the transition function actually calls it on active -> draft.
    const trans = plan.match(/create or replace function _saboteur_apply_transition[\s\S]*?\nend \$\$;/i)[0]
    expect(trans).toMatch(/v_game\.status = 'active' and p_new_status = 'draft'[\s\S]{0,120}_saboteur_undeal_planned/)
    expect(trans).toMatch(/v_game\.status = 'draft' and p_new_status = 'active'[\s\S]{0,200}_saboteur_deal_planned/)
  })

  it('an ended game can be reopened, and the end-of-game bonus recomputed', () => {
    const plan = read('supabase/migrations/00024_plan_ahead.sql')
    const trans = plan.match(/create or replace function _saboteur_apply_transition[\s\S]*?\nend \$\$;/i)[0]

    expect(trans).toMatch(/\('ended', 'active'\)/)
    // The undetected bonus is a calculation made at the finish line. Move the
    // line and it has to be redone - the ledger is idempotent, so a stale row
    // would otherwise block the recount forever.
    expect(trans).toMatch(/delete from saboteur_points_ledger[\s\S]{0,200}source_type = 'undetected'/)
    // Everything else - approved missions, correct votes, host bonuses - is a
    // historical fact and must survive a reopen.
    expect(trans).not.toMatch(/delete from saboteur_points_ledger[\s\S]{0,200}source_type in/)

    expect(plan).toMatch(/create or replace function host_reopen_saboteur_game/i)
    expect(plan).toMatch(/Bare et avsluttet spill kan åpnes igjen/)
  })

  it('an orphaned bundle cannot deadlock the voting gate', () => {
    const plan = read('supabase/migrations/00024_plan_ahead.sql')
    const open = plan.match(/create or replace function host_open_voting_round[\s\S]*?\nend \$\$;/i)[0]
    // 00023 blocks voting on unsettled objectives. A bundle nobody received
    // can never be settled, so it must not count - otherwise planning for
    // three Sabotorer and running with two locks voting for the whole night.
    expect(open).toMatch(/assigned_participant_id is not null[\s\S]{0,80}published and status in \('assigned', 'claimed'\)/)
    const hostGet = plan.match(/create or replace function host_get_saboteur_game[\s\S]*?\nend \$\$;/i)[0]
    expect(hostGet).toMatch(/'unsettled_objectives'[\s\S]{0,200}assigned_participant_id is not null/)
  })

  it('the new objective signatures replace the old ones outright', () => {
    const plan = read('supabase/migrations/00024_plan_ahead.sql')
    // Leaving both overloads in place makes every call ambiguous to PostgREST.
    expect(plan).toMatch(/drop function if exists host_upsert_objective\(uuid, uuid, uuid, text, text, int, timestamptz\)/)
    expect(plan).toMatch(/drop function if exists host_add_objective_from_library\(uuid, uuid, uuid\)/)
    expect(plan).toMatch(/grant execute on function host_upsert_objective\(uuid, uuid, uuid, text, text, int, timestamptz, smallint\)/)
    expect(read('supabase/migrations/00020_migration_tracking.sql')).toMatch(/'00024_plan_ahead'/)
  })

  it('canonical supabase-schema.sql matches the standalone model', () => {
    expect(schemaFile).toMatch(/SABOTEUR_GAME_ENABLED/)
    expect(schemaFile).toMatch(/create or replace function create_saboteur_game\(/i)
    expect(schemaFile).toMatch(/create or replace function join_saboteur_game\(/i)
    // The canonical file is now the migrations replayed in order, so the old
    // party-bound functions DO appear — created by 00009/00010 and then
    // dropped by 00011. What matters is that the drop comes last, leaving
    // them absent from the final state.
    for (const fn of ['get_my_saboteur_game_id', 'host_list_eligible_participants']) {
      const created = schemaFile.lastIndexOf(`create or replace function ${fn}`)
      const dropped = schemaFile.lastIndexOf(`drop function if exists ${fn}`)
      expect(dropped, `${fn} should be dropped somewhere`).toBeGreaterThan(-1)
      expect(dropped, `${fn} must be dropped AFTER its last creation`).toBeGreaterThan(created)
    }
  })
})
