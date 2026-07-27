-- ============================================================================
-- MIGRASJON 00009 — Skjult agenda (hidden-identity social deduction mode)
--
-- A fully additive, opt-in game mode layered INSIDE an existing party
-- (games row). Nothing here alters or is read by the murder-mystery tables.
--
-- REUSE, NOT REDESIGN:
--   - "party/session"      -> an existing games.id (unchanged table)
--   - "eligible players"   -> existing players rows for that game_id
--   - "host / game-master" -> the SAME host_token that already controls that
--                             games row, resolved via the EXISTING _host_game()
--   - "player identity"    -> the SAME player_token each guest already has,
--                             resolved via the EXISTING _player()
--   No second auth model, no new accounts, no auth.uid() requirement — this
--   works for anonymous host_token-only hosting exactly like the rest of
--   the app, by deliberate choice (see the approved Phase 1 plan).
--
-- FEATURE FLAG (default OFF everywhere, enforced server-side):
--   app_feature_flags('SABOTEUR_GAME_ENABLED') is checked as the FIRST
--   statement of every single RPC below, before any token is even resolved.
--   With the flag off, every RPC refuses identically regardless of token
--   validity — a guessed call from devtools cannot enable or probe anything.
--   A client-side VITE_SABOTEUR_GAME_ENABLED build flag additionally hides
--   the UI entry points, but the server check above is the real gate.
--
-- SECRECY MODEL (same idiom as the rest of this schema):
--   RLS enabled, ZERO policies, all grants revoked from anon/authenticated
--   on every new table. All access goes through SECURITY DEFINER RPCs that
--   hand-build minimal, viewer-specific JSON (never `select *`). Two new
--   internal helpers mirror _host_game/_player exactly, and additionally
--   verify the resolved saboteur row belongs to the CALLER'S OWN game_id —
--   this is what stops cross-game ID tampering even with a valid token.
--
-- VOTE SECRECY — an interpretation worth stating explicitly: "votes stay
--   secret until Vertskontroll closes and explicitly reveals" is read here
--   as applying even to the host's own live view, not just to players — the
--   host sees a live ballot COUNT while a round is open, but the per-target
--   tally is only computed and returned once the host has both closed AND
--   explicitly revealed that round. This matches "Do not reveal roles
--   merely because a vote has happened."
--
-- Idempotent (safe to re-run): create-if-not-exists / create-or-replace
-- throughout, feature flag seeded only if missing.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) FEATURE FLAG
-- ----------------------------------------------------------------------------

create table if not exists app_feature_flags (
  key     text primary key,
  enabled boolean not null default false
);

insert into app_feature_flags (key, enabled)
values ('SABOTEUR_GAME_ENABLED', false)
on conflict (key) do nothing;

alter table app_feature_flags enable row level security;
revoke all on app_feature_flags from anon, authenticated;

-- Internal-only: no client role may call this directly (revoked below with
-- the rest). Every public RPC in this file calls it as its first statement.
create or replace function _saboteur_enabled()
returns boolean
language sql security definer set search_path = public
as $$
  select coalesce((select enabled from app_feature_flags where key = 'SABOTEUR_GAME_ENABLED'), false);
$$;

revoke execute on function _saboteur_enabled() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 1) TABELLER (all additive; nothing existing is touched)
-- ----------------------------------------------------------------------------

create table if not exists saboteur_games (
  id               uuid primary key default gen_random_uuid(),
  game_id          uuid not null references games (id) on delete cascade,
  status           text not null default 'draft'
                   check (status in ('draft','active','voting','paused','ended','archived')),
  know_each_other  boolean not null default false,
  show_leaderboard boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Only one non-archived Skjult agenda per fest at a time (approved scope).
create unique index if not exists saboteur_games_one_active_per_game
  on saboteur_games (game_id) where status <> 'archived';
create index if not exists saboteur_games_game_idx on saboteur_games (game_id);

create table if not exists saboteur_participants (
  id               uuid primary key default gen_random_uuid(),
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  player_id        uuid not null references players (id) on delete cascade,
  role             text not null check (role in ('SABOTEUR','LOYAL')),
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  unique (saboteur_game_id, player_id)
);
create index if not exists saboteur_participants_game_idx on saboteur_participants (saboteur_game_id);
create index if not exists saboteur_participants_player_idx on saboteur_participants (player_id);

create table if not exists saboteur_objectives (
  id                      uuid primary key default gen_random_uuid(),
  saboteur_game_id        uuid not null references saboteur_games (id) on delete cascade,
  assigned_participant_id uuid not null references saboteur_participants (id) on delete cascade,
  title                   text not null,
  description             text not null default '',
  points                  int  not null default 0 check (points >= 0),
  expires_at              timestamptz,
  status                  text not null default 'assigned'
                          check (status in ('assigned','claimed','approved','rejected')),
  claimed_at              timestamptz,
  decided_at              timestamptz,
  created_at              timestamptz not null default now()
);
create index if not exists saboteur_objectives_game_idx on saboteur_objectives (saboteur_game_id);
create index if not exists saboteur_objectives_participant_idx on saboteur_objectives (assigned_participant_id);

create table if not exists saboteur_tasks (
  id                      uuid primary key default gen_random_uuid(),
  saboteur_game_id        uuid not null references saboteur_games (id) on delete cascade,
  assigned_participant_id uuid not null references saboteur_participants (id) on delete cascade,
  title                   text not null,
  description             text not null default '',
  hint_text               text not null default '',
  hint_audience           text not null default 'assignee' check (hint_audience in ('assignee','all_loyal')),
  status                  text not null default 'assigned'
                          check (status in ('assigned','claimed','approved','rejected')),
  claimed_at              timestamptz,
  decided_at              timestamptz,
  created_at              timestamptz not null default now()
);
create index if not exists saboteur_tasks_game_idx on saboteur_tasks (saboteur_game_id);
create index if not exists saboteur_tasks_participant_idx on saboteur_tasks (assigned_participant_id);

-- Append-only: decouples "who is entitled to see this hint" from re-deriving
-- audience logic on every read, and makes release idempotent (see below).
create table if not exists saboteur_hint_releases (
  id                         uuid primary key default gen_random_uuid(),
  task_id                    uuid not null references saboteur_tasks (id) on delete cascade,
  released_to_participant_id uuid not null references saboteur_participants (id) on delete cascade,
  created_at                 timestamptz not null default now(),
  unique (task_id, released_to_participant_id)
);
create index if not exists saboteur_hint_releases_participant_idx on saboteur_hint_releases (released_to_participant_id);

create table if not exists saboteur_voting_rounds (
  id               uuid primary key default gen_random_uuid(),
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  status           text not null default 'open' check (status in ('open','closed','revealed')),
  opened_at        timestamptz not null default now(),
  closed_at        timestamptz,
  revealed_at      timestamptz
);
-- Only one OPEN round per Skjult agenda at a time.
create unique index if not exists saboteur_voting_rounds_one_open
  on saboteur_voting_rounds (saboteur_game_id) where status = 'open';
create index if not exists saboteur_voting_rounds_game_idx on saboteur_voting_rounds (saboteur_game_id);

create table if not exists saboteur_ballots (
  id                    uuid primary key default gen_random_uuid(),
  voting_round_id       uuid not null references saboteur_voting_rounds (id) on delete cascade,
  voter_participant_id  uuid not null references saboteur_participants (id) on delete cascade,
  target_participant_id uuid not null references saboteur_participants (id) on delete cascade,
  created_at            timestamptz not null default now(),
  -- THE one-ballot-per-eligible-Lojal-per-round guarantee, enforced by the
  -- database itself, not just application logic.
  unique (voting_round_id, voter_participant_id)
);
create index if not exists saboteur_ballots_round_idx on saboteur_ballots (voting_round_id);
create index if not exists saboteur_ballots_target_idx on saboteur_ballots (target_participant_id);

-- Append-only score events (never mutate a running total column) — current
-- score = sum(points) for a participant. The partial unique index below is
-- the idempotency guarantee: approving the same objective twice (a retried
-- request) cannot insert a second row for the same source_id.
create table if not exists saboteur_points_ledger (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references saboteur_participants (id) on delete cascade,
  source_type    text not null check (source_type in ('objective','adjustment')),
  source_id      uuid,
  points         int not null,
  created_at     timestamptz not null default now()
);
create unique index if not exists saboteur_points_ledger_idempotent
  on saboteur_points_ledger (source_type, source_id) where source_id is not null;
create index if not exists saboteur_points_ledger_participant_idx on saboteur_points_ledger (participant_id);

-- Append-only audit trail for every host action that materially affects the
-- game. Host-only readable (host_get_saboteur_audit).
create table if not exists saboteur_audit_log (
  id               bigint generated always as identity primary key,
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  actor            text not null default 'host',
  action           text not null,
  payload          jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now()
);
create index if not exists saboteur_audit_log_game_idx on saboteur_audit_log (saboteur_game_id, id);

-- ----------------------------------------------------------------------------
-- 2) RLS: enabled, ZERO policies on every new table (identical idiom to the
--    rest of this schema). All access is via the RPCs in section 4/5.
-- ----------------------------------------------------------------------------

alter table saboteur_games          enable row level security;
alter table saboteur_participants   enable row level security;
alter table saboteur_objectives     enable row level security;
alter table saboteur_tasks          enable row level security;
alter table saboteur_hint_releases  enable row level security;
alter table saboteur_voting_rounds  enable row level security;
alter table saboteur_ballots        enable row level security;
alter table saboteur_points_ledger  enable row level security;
alter table saboteur_audit_log      enable row level security;

revoke all on saboteur_games, saboteur_participants, saboteur_objectives, saboteur_tasks,
  saboteur_hint_releases, saboteur_voting_rounds, saboteur_ballots, saboteur_points_ledger,
  saboteur_audit_log
  from anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3) INTERNE HJELPEFUNKSJONER (mirror _host_game / _player exactly)
-- ----------------------------------------------------------------------------

-- Resolves p_host_token via the EXISTING _host_game(), then requires the
-- saboteur_games row to belong to THAT host's own games.id. A valid
-- host_token can never unlock a Skjult agenda belonging to someone else's
-- party — this is the cross-game-tampering guard.
create or replace function _saboteur_game_for_host(p_host_token uuid, p_saboteur_game_id uuid)
returns saboteur_games
language plpgsql security definer set search_path = public
as $$
declare
  v_game    games := _host_game(p_host_token);
  v_sabgame saboteur_games;
begin
  select * into v_sabgame from saboteur_games
  where id = p_saboteur_game_id and game_id = v_game.id;
  if not found then
    raise exception 'Fant ikke Skjult agenda-spillet';
  end if;
  return v_sabgame;
end $$;

revoke execute on function _saboteur_game_for_host(uuid, uuid) from public, anon, authenticated;

-- Same guarantee for a player: resolves p_player_token via the EXISTING
-- _player(), then requires a saboteur_participants row for THIS player in a
-- saboteur_game that belongs to the player's own game_id.
create or replace function _saboteur_participant_for_player(p_player_token uuid, p_saboteur_game_id uuid)
returns saboteur_participants
language plpgsql security definer set search_path = public
as $$
declare
  v_player  players := _player(p_player_token);
  v_sabgame saboteur_games;
  v_part    saboteur_participants;
begin
  select * into v_sabgame from saboteur_games
  where id = p_saboteur_game_id and game_id = v_player.game_id;
  if not found then
    raise exception 'Fant ikke Skjult agenda-spillet';
  end if;

  select * into v_part from saboteur_participants
  where saboteur_game_id = v_sabgame.id and player_id = v_player.id;
  if not found then
    raise exception 'Du er ikke med i dette spillet';
  end if;
  return v_part;
end $$;

revoke execute on function _saboteur_participant_for_player(uuid, uuid) from public, anon, authenticated;

create or replace function _saboteur_audit(p_saboteur_game_id uuid, p_action text, p_payload jsonb default '{}'::jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into saboteur_audit_log (saboteur_game_id, actor, action, payload)
  values (p_saboteur_game_id, 'host', p_action, p_payload);
end $$;

revoke execute on function _saboteur_audit(uuid, text, jsonb) from public, anon, authenticated;

-- Shared status-transition applier (one allowed-edges table, used by
-- host_set_saboteur_status / host_end_saboteur_game / host_archive_saboteur_game).
-- 'voting' is deliberately NOT settable here: that transition has side
-- effects (creating/closing a round) and only happens via the two dedicated
-- voting-round RPCs below.
create or replace function _saboteur_apply_transition(p_saboteur_game_id uuid, p_new_status text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_ok   boolean;
begin
  select * into v_game from saboteur_games where id = p_saboteur_game_id;

  if v_game.status = 'voting' then
    raise exception 'Lukk avstemningsrunden først (host_close_voting_round)';
  end if;
  if p_new_status = 'voting' then
    raise exception 'Bruk host_open_voting_round for å åpne en avstemningsrunde';
  end if;

  v_ok := (v_game.status, p_new_status) in (
    ('draft', 'active'), ('active', 'draft'),
    ('active', 'paused'), ('paused', 'active'),
    ('active', 'ended'), ('paused', 'ended'),
    ('ended', 'archived')
  );
  if not v_ok then
    raise exception 'Kan ikke gå fra «%» til «%»', v_game.status, p_new_status;
  end if;

  if v_game.status = 'draft' and p_new_status = 'active' then
    if (select count(distinct role) from saboteur_participants
        where saboteur_game_id = p_saboteur_game_id and active) < 2 then
      raise exception 'Trenger minst én Sabotør og én Lojal før spillet kan starte';
    end if;
  end if;

  update saboteur_games set status = p_new_status, updated_at = now() where id = p_saboteur_game_id;

  perform _saboteur_audit(
    p_saboteur_game_id,
    case when v_game.status = 'active' and p_new_status = 'draft' then 'reopen_roles' else 'state_change' end,
    jsonb_build_object('from', v_game.status, 'to', p_new_status)
  );
end $$;

revoke execute on function _saboteur_apply_transition(uuid, text) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4) RPC: VERTSKONTROLL (host_token; every function checks the flag FIRST,
--    before resolving any token, so a disabled feature refuses identically
--    regardless of token validity)
-- ----------------------------------------------------------------------------

create or replace function host_create_saboteur_game(p_host_token uuid, p_know_each_other boolean default false)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game    games;
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _host_game(p_host_token);

  begin
    insert into saboteur_games (game_id, know_each_other)
    values (v_game.id, coalesce(p_know_each_other, false))
    returning * into v_sabgame;
  exception when unique_violation then
    raise exception 'Det finnes allerede en aktiv Skjult agenda for denne festen';
  end;

  perform _saboteur_audit(v_sabgame.id, 'game_created', jsonb_build_object('know_each_other', v_sabgame.know_each_other));
  return json_build_object('saboteur_game_id', v_sabgame.id, 'status', v_sabgame.status);
end $$;

create or replace function host_list_eligible_participants(p_host_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game    games;
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  return (
    select coalesce(json_agg(json_build_object(
      'player_id', p.id, 'display_name', p.display_name,
      'included', sp.id is not null, 'role', sp.role, 'active', coalesce(sp.active, true)
    ) order by p.joined_at), '[]'::json)
    from players p
    left join saboteur_participants sp
      on sp.player_id = p.id and sp.saboteur_game_id = v_sabgame.id
    where p.game_id = v_game.id
  );
end $$;

-- p_assignments: jsonb array of {"player_id": uuid, "role": "SABOTEUR"|"LOYAL"|null}.
-- role = null removes that player from the Skjult agenda. Draft-only.
create or replace function host_set_participants(p_host_token uuid, p_saboteur_game_id uuid, p_assignments jsonb)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game      games;
  v_sabgame   saboteur_games;
  v_item      jsonb;
  v_player_id uuid;
  v_role      text;
  v_count     int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  if v_sabgame.status <> 'draft' then
    raise exception 'Roller kan bare endres mens spillet er i utkast';
  end if;

  for v_item in select * from jsonb_array_elements(coalesce(p_assignments, '[]'::jsonb))
  loop
    v_player_id := (v_item ->> 'player_id')::uuid;
    v_role := nullif(v_item ->> 'role', '');

    perform 1 from players where id = v_player_id and game_id = v_game.id;
    if not found then
      raise exception 'Ukjent spiller i denne festen';
    end if;

    if v_role is null then
      delete from saboteur_participants where saboteur_game_id = v_sabgame.id and player_id = v_player_id;
    else
      if v_role not in ('SABOTEUR', 'LOYAL') then
        raise exception 'Ukjent rolle: %', v_role;
      end if;
      insert into saboteur_participants (saboteur_game_id, player_id, role)
      values (v_sabgame.id, v_player_id, v_role)
      on conflict (saboteur_game_id, player_id) do update set role = excluded.role, active = true;
    end if;
    v_count := v_count + 1;
  end loop;

  perform _saboteur_audit(v_sabgame.id, 'set_participants', p_assignments);
  return json_build_object('ok', true, 'processed', v_count);
end $$;

create or replace function host_set_participant_active(p_host_token uuid, p_saboteur_game_id uuid, p_player_id uuid, p_active boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  update saboteur_participants set active = coalesce(p_active, true)
  where saboteur_game_id = v_sabgame.id and player_id = p_player_id;
  if not found then
    raise exception 'Ukjent deltaker';
  end if;

  perform _saboteur_audit(v_sabgame.id, 'set_participant_active', jsonb_build_object('player_id', p_player_id, 'active', p_active));
  return json_build_object('ok', true);
end $$;

create or replace function host_set_know_each_other(p_host_token uuid, p_saboteur_game_id uuid, p_enabled boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  if v_sabgame.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;

  update saboteur_games set know_each_other = coalesce(p_enabled, false), updated_at = now() where id = v_sabgame.id;
  perform _saboteur_audit(v_sabgame.id, 'set_know_each_other', jsonb_build_object('enabled', p_enabled));
  return json_build_object('ok', true);
end $$;

create or replace function host_set_show_leaderboard(p_host_token uuid, p_saboteur_game_id uuid, p_enabled boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  update saboteur_games set show_leaderboard = coalesce(p_enabled, false), updated_at = now() where id = v_sabgame.id;
  perform _saboteur_audit(v_sabgame.id, 'set_show_leaderboard', jsonb_build_object('enabled', p_enabled));
  return json_build_object('ok', true);
end $$;

create or replace function host_set_saboteur_status(p_host_token uuid, p_saboteur_game_id uuid, p_status text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  perform _saboteur_apply_transition(v_sabgame.id, p_status);
  return json_build_object('ok', true, 'status', p_status);
end $$;

create or replace function host_end_saboteur_game(p_host_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  perform _saboteur_apply_transition(v_sabgame.id, 'ended');
  return json_build_object('ok', true);
end $$;

create or replace function host_archive_saboteur_game(p_host_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  perform _saboteur_apply_transition(v_sabgame.id, 'archived');
  return json_build_object('ok', true);
end $$;

create or replace function host_upsert_objective(
  p_host_token uuid, p_saboteur_game_id uuid, p_objective_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_points int default 0, p_expires_at timestamptz default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
  v_id      uuid;
  v_title   text := trim(coalesce(p_title, ''));
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  if v_sabgame.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;

  if p_objective_id is null then
    if v_title = '' then
      raise exception 'Målet trenger en tittel';
    end if;
    perform 1 from saboteur_participants
      where id = p_participant_id and saboteur_game_id = v_sabgame.id and role = 'SABOTEUR';
    if not found then
      raise exception 'Målet må tildeles en Sabotør i dette spillet';
    end if;

    insert into saboteur_objectives (saboteur_game_id, assigned_participant_id, title, description, points, expires_at)
    values (v_sabgame.id, p_participant_id, v_title, coalesce(p_description, ''), coalesce(p_points, 0), p_expires_at)
    returning id into v_id;
  else
    update saboteur_objectives set
      title       = coalesce(nullif(trim(p_title), ''), title),
      description = coalesce(p_description, description),
      points      = coalesce(p_points, points),
      expires_at  = coalesce(p_expires_at, expires_at)
    where id = p_objective_id and saboteur_game_id = v_sabgame.id;
    if not found then
      raise exception 'Ukjent mål';
    end if;
    v_id := p_objective_id;
  end if;

  perform _saboteur_audit(v_sabgame.id, 'objective_upsert', jsonb_build_object('objective_id', v_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_decide_objective_claim(p_host_token uuid, p_saboteur_game_id uuid, p_objective_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame  saboteur_games;
  v_obj      saboteur_objectives;
  v_rowcount int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  select * into v_obj from saboteur_objectives where id = p_objective_id and saboteur_game_id = v_sabgame.id;
  if not found then
    raise exception 'Ukjent mål';
  end if;

  if v_obj.status in ('approved', 'rejected') then
    -- Already decided: idempotent no-op. Retries can never re-score or re-flip.
    return json_build_object('ok', true, 'status', v_obj.status, 'already_decided', true);
  end if;
  if v_obj.status <> 'claimed' then
    raise exception 'Målet er ikke krevd av Sabotøren ennå';
  end if;

  if p_approve then
    update saboteur_objectives set status = 'approved', decided_at = now() where id = v_obj.id;
    insert into saboteur_points_ledger (participant_id, source_type, source_id, points)
    values (v_obj.assigned_participant_id, 'objective', v_obj.id, v_obj.points)
    on conflict (source_type, source_id) where source_id is not null do nothing;
    get diagnostics v_rowcount = row_count;
  else
    update saboteur_objectives set status = 'rejected', decided_at = now() where id = v_obj.id;
  end if;

  perform _saboteur_audit(v_sabgame.id, 'objective_decided',
    jsonb_build_object('objective_id', v_obj.id, 'approved', p_approve, 'points_awarded', v_rowcount > 0));
  return json_build_object('ok', true, 'status', case when p_approve then 'approved' else 'rejected' end,
    'points_awarded', v_rowcount > 0);
end $$;

create or replace function host_upsert_task(
  p_host_token uuid, p_saboteur_game_id uuid, p_task_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_hint_text text default null, p_hint_audience text default 'assignee'
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame  saboteur_games;
  v_id       uuid;
  v_title    text := trim(coalesce(p_title, ''));
  v_audience text := coalesce(p_hint_audience, 'assignee');
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  if v_sabgame.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;
  if v_audience not in ('assignee', 'all_loyal') then
    raise exception 'Ukjent mottakergruppe for hintet';
  end if;

  if p_task_id is null then
    if v_title = '' then
      raise exception 'Oppgaven trenger en tittel';
    end if;
    perform 1 from saboteur_participants
      where id = p_participant_id and saboteur_game_id = v_sabgame.id and role = 'LOYAL';
    if not found then
      raise exception 'Oppgaven må tildeles en Lojal i dette spillet';
    end if;

    insert into saboteur_tasks (saboteur_game_id, assigned_participant_id, title, description, hint_text, hint_audience)
    values (v_sabgame.id, p_participant_id, v_title, coalesce(p_description, ''), coalesce(p_hint_text, ''), v_audience)
    returning id into v_id;
  else
    update saboteur_tasks set
      title         = coalesce(nullif(trim(p_title), ''), title),
      description   = coalesce(p_description, description),
      hint_text     = coalesce(p_hint_text, hint_text),
      hint_audience = coalesce(p_hint_audience, hint_audience)
    where id = p_task_id and saboteur_game_id = v_sabgame.id;
    if not found then
      raise exception 'Ukjent oppgave';
    end if;
    v_id := p_task_id;
  end if;

  perform _saboteur_audit(v_sabgame.id, 'task_upsert', jsonb_build_object('task_id', v_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_decide_task_claim(p_host_token uuid, p_saboteur_game_id uuid, p_task_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame  saboteur_games;
  v_task     saboteur_tasks;
  v_released int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  select * into v_task from saboteur_tasks where id = p_task_id and saboteur_game_id = v_sabgame.id;
  if not found then
    raise exception 'Ukjent oppgave';
  end if;

  if v_task.status in ('approved', 'rejected') then
    return json_build_object('ok', true, 'status', v_task.status, 'already_decided', true);
  end if;
  if v_task.status <> 'claimed' then
    raise exception 'Oppgaven er ikke krevd av spilleren ennå';
  end if;

  if p_approve then
    update saboteur_tasks set status = 'approved', decided_at = now() where id = v_task.id;

    if v_task.hint_audience = 'all_loyal' then
      insert into saboteur_hint_releases (task_id, released_to_participant_id)
      select v_task.id, sp.id from saboteur_participants sp
      where sp.saboteur_game_id = v_sabgame.id and sp.role = 'LOYAL' and sp.active
      on conflict (task_id, released_to_participant_id) do nothing;
    else
      insert into saboteur_hint_releases (task_id, released_to_participant_id)
      values (v_task.id, v_task.assigned_participant_id)
      on conflict (task_id, released_to_participant_id) do nothing;
    end if;
    get diagnostics v_released = row_count;
  else
    update saboteur_tasks set status = 'rejected', decided_at = now() where id = v_task.id;
  end if;

  perform _saboteur_audit(v_sabgame.id, 'task_decided',
    jsonb_build_object('task_id', v_task.id, 'approved', p_approve, 'hints_released', v_released));
  return json_build_object('ok', true, 'status', case when p_approve then 'approved' else 'rejected' end);
end $$;

create or replace function host_open_voting_round(p_host_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
  v_round   saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  if v_sabgame.status <> 'active' then
    raise exception 'Spillet må være aktivt for å åpne en avstemning';
  end if;

  begin
    insert into saboteur_voting_rounds (saboteur_game_id) values (v_sabgame.id) returning * into v_round;
  exception when unique_violation then
    raise exception 'Det er allerede en åpen avstemningsrunde';
  end;

  update saboteur_games set status = 'voting', updated_at = now() where id = v_sabgame.id;
  perform _saboteur_audit(v_sabgame.id, 'voting_opened', jsonb_build_object('round_id', v_round.id));
  return json_build_object('ok', true, 'round_id', v_round.id);
end $$;

create or replace function host_close_voting_round(p_host_token uuid, p_saboteur_game_id uuid, p_round_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
  v_round   saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  select * into v_round from saboteur_voting_rounds where id = p_round_id and saboteur_game_id = v_sabgame.id;
  if not found then
    raise exception 'Ukjent avstemningsrunde';
  end if;
  if v_round.status <> 'open' then
    raise exception 'Runden er ikke åpen';
  end if;

  update saboteur_voting_rounds set status = 'closed', closed_at = now() where id = v_round.id;
  update saboteur_games set status = 'active', updated_at = now() where id = v_sabgame.id;
  perform _saboteur_audit(v_sabgame.id, 'voting_closed', jsonb_build_object('round_id', v_round.id));
  return json_build_object('ok', true);
end $$;

create or replace function host_reveal_voting_round(p_host_token uuid, p_saboteur_game_id uuid, p_round_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
  v_round   saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  select * into v_round from saboteur_voting_rounds where id = p_round_id and saboteur_game_id = v_sabgame.id;
  if not found then
    raise exception 'Ukjent avstemningsrunde';
  end if;
  if v_round.status <> 'closed' then
    raise exception 'Lukk runden før den kan avsløres';
  end if;

  update saboteur_voting_rounds set status = 'revealed', revealed_at = now() where id = v_round.id;
  perform _saboteur_audit(v_sabgame.id, 'voting_revealed', jsonb_build_object('round_id', v_round.id));
  return json_build_object('ok', true);
end $$;

-- The full control-panel read. Host sees every role/task/claim/hint/score;
-- vote TARGET-level tally only once the round is both closed and revealed
-- (see the header comment on vote secrecy) — a live ballot count is shown
-- while a round is open so the host knows when to close it.
create or replace function host_get_saboteur_game(p_host_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
  v_round   saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_sabgame.id order by opened_at desc limit 1;

  return json_build_object(
    'id', v_sabgame.id, 'status', v_sabgame.status,
    'know_each_other', v_sabgame.know_each_other, 'show_leaderboard', v_sabgame.show_leaderboard,
    'created_at', v_sabgame.created_at,

    'participants', (
      select coalesce(json_agg(json_build_object(
        'id', sp.id, 'player_id', sp.player_id, 'display_name', p.display_name,
        'role', sp.role, 'active', sp.active,
        'points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = sp.id)
      ) order by p.joined_at), '[]'::json)
      from saboteur_participants sp join players p on p.id = sp.player_id
      where sp.saboteur_game_id = v_sabgame.id
    ),

    'objectives', (
      select coalesce(json_agg(json_build_object(
        'id', o.id, 'participant_id', o.assigned_participant_id, 'title', o.title,
        'description', o.description, 'points', o.points, 'expires_at', o.expires_at,
        'status', o.status, 'claimed_at', o.claimed_at, 'decided_at', o.decided_at
      ) order by o.created_at), '[]'::json)
      from saboteur_objectives o where o.saboteur_game_id = v_sabgame.id
    ),

    'tasks', (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'participant_id', t.assigned_participant_id, 'title', t.title,
        'description', t.description, 'hint_text', t.hint_text, 'hint_audience', t.hint_audience,
        'status', t.status, 'claimed_at', t.claimed_at, 'decided_at', t.decided_at
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t where t.saboteur_game_id = v_sabgame.id
    ),

    'current_round', case when v_round.id is null then null else json_build_object(
      'id', v_round.id, 'status', v_round.status,
      'opened_at', v_round.opened_at, 'closed_at', v_round.closed_at, 'revealed_at', v_round.revealed_at,
      'ballot_count', (select count(*) from saboteur_ballots b where b.voting_round_id = v_round.id),
      'tally', case when v_round.status = 'revealed' then (
        select coalesce(json_agg(json_build_object(
          'participant_id', t.target_participant_id, 'display_name', p.display_name, 'votes', t.votes
        ) order by t.votes desc), '[]'::json)
        from (
          select target_participant_id, count(*) as votes
          from saboteur_ballots where voting_round_id = v_round.id
          group by target_participant_id
        ) t
        join saboteur_participants sp on sp.id = t.target_participant_id
        join players p on p.id = sp.player_id
      ) else null end
    ) end
  );
end $$;

create or replace function host_get_saboteur_audit(p_host_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _host_game(p_host_token);
  v_sabgame := _saboteur_game_for_host(p_host_token, p_saboteur_game_id);

  return (
    select coalesce(json_agg(json_build_object(
      'id', a.id, 'actor', a.actor, 'action', a.action, 'payload', a.payload, 'created_at', a.created_at
    ) order by a.id), '[]'::json)
    from saboteur_audit_log a where a.saboteur_game_id = v_sabgame.id
  );
end $$;

-- ----------------------------------------------------------------------------
-- 5) RPC: SPILLERE (player_token; NEVER returns another participant's role,
--    objectives, tasks, hints, or any ballot data)
-- ----------------------------------------------------------------------------

create or replace function get_my_saboteur_brief(p_player_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part    saboteur_participants;
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_participant_for_player(p_player_token, p_saboteur_game_id);
  select * into v_sabgame from saboteur_games where id = v_part.saboteur_game_id;

  return json_build_object(
    'saboteur_game_id', v_sabgame.id, 'status', v_sabgame.status,
    'my_role', v_part.role, 'my_active', v_part.active,

    'fellow_saboteurs', case when v_part.role = 'SABOTEUR' and v_sabgame.know_each_other then (
      select coalesce(json_agg(json_build_object('display_name', p.display_name)), '[]'::json)
      from saboteur_participants sp join players p on p.id = sp.player_id
      where sp.saboteur_game_id = v_sabgame.id and sp.role = 'SABOTEUR' and sp.id <> v_part.id
    ) else '[]'::json end,

    'objectives', case when v_part.role = 'SABOTEUR' then (
      select coalesce(json_agg(json_build_object(
        'id', o.id, 'title', o.title, 'description', o.description, 'points', o.points,
        'expires_at', o.expires_at, 'status', o.status
      ) order by o.created_at), '[]'::json)
      from saboteur_objectives o where o.assigned_participant_id = v_part.id
    ) else '[]'::json end,

    'tasks', case when v_part.role = 'LOYAL' then (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'title', t.title, 'description', t.description, 'status', t.status
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t where t.assigned_participant_id = v_part.id
    ) else '[]'::json end,

    -- Only rows explicitly released to ME (see host_decide_task_claim) —
    -- never derived generically from "am I Lojal", so an all_loyal release
    -- for one task never leaks a DIFFERENT task's hint to the same player.
    'hints', (
      select coalesce(json_agg(json_build_object(
        'task_id', hr.task_id, 'hint_text', t.hint_text, 'released_at', hr.created_at
      ) order by hr.created_at), '[]'::json)
      from saboteur_hint_releases hr join saboteur_tasks t on t.id = hr.task_id
      where hr.released_to_participant_id = v_part.id
    ),

    'reveal', case when v_sabgame.status = 'ended' then json_build_object(
      'participants', (
        select coalesce(json_agg(json_build_object('display_name', p.display_name, 'role', sp.role) order by p.display_name), '[]'::json)
        from saboteur_participants sp join players p on p.id = sp.player_id
        where sp.saboteur_game_id = v_sabgame.id
      ),
      'my_points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = v_part.id),
      'leaderboard', case when v_sabgame.show_leaderboard then (
        select coalesce(json_agg(json_build_object('display_name', x.display_name, 'points', x.points) order by x.points desc), '[]'::json)
        from (
          select p.display_name, coalesce(sum(pl.points), 0) as points
          from saboteur_participants sp
          join players p on p.id = sp.player_id
          left join saboteur_points_ledger pl on pl.participant_id = sp.id
          where sp.saboteur_game_id = v_sabgame.id
          group by sp.id, p.display_name
        ) x
      ) else null end
    ) else null end
  );
end $$;

create or replace function get_my_saboteur_vote_status(p_player_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
  v_voted boolean := false;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_participant_for_player(p_player_token, p_saboteur_game_id);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = p_saboteur_game_id and status = 'open' limit 1;

  if v_round.id is not null then
    select exists(
      select 1 from saboteur_ballots where voting_round_id = v_round.id and voter_participant_id = v_part.id
    ) into v_voted;
  end if;

  return json_build_object(
    'can_vote', v_round.id is not null and v_part.role = 'LOYAL' and v_part.active and not v_voted,
    'round_open', v_round.id is not null, 'round_id', v_round.id, 'already_voted', v_voted
  );
end $$;

create or replace function get_saboteur_ballot_targets(p_player_token uuid, p_saboteur_game_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_participant_for_player(p_player_token, p_saboteur_game_id);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = p_saboteur_game_id and status = 'open' limit 1;

  if v_round.id is null or v_part.role <> 'LOYAL' or not v_part.active then
    return '[]'::json;
  end if;

  return (
    select coalesce(json_agg(json_build_object('participant_id', sp.id, 'display_name', p.display_name) order by p.display_name), '[]'::json)
    from saboteur_participants sp join players p on p.id = sp.player_id
    where sp.saboteur_game_id = p_saboteur_game_id and sp.active
  );
end $$;

create or replace function cast_saboteur_ballot(p_player_token uuid, p_saboteur_game_id uuid, p_round_id uuid, p_target_participant_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_participant_for_player(p_player_token, p_saboteur_game_id);

  if v_part.role <> 'LOYAL' or not v_part.active then
    raise exception 'Du kan ikke stemme i denne avstemningen';
  end if;

  select * into v_round from saboteur_voting_rounds
  where id = p_round_id and saboteur_game_id = p_saboteur_game_id and status = 'open';
  if not found then
    raise exception 'Avstemningen er ikke åpen';
  end if;

  perform 1 from saboteur_participants
  where id = p_target_participant_id and saboteur_game_id = p_saboteur_game_id and active;
  if not found then
    raise exception 'Ukjent stemmemål';
  end if;

  begin
    insert into saboteur_ballots (voting_round_id, voter_participant_id, target_participant_id)
    values (v_round.id, v_part.id, p_target_participant_id);
  exception when unique_violation then
    raise exception 'Du har allerede stemt i denne runden';
  end;

  return json_build_object('ok', true);
end $$;

create or replace function claim_saboteur_objective(p_player_token uuid, p_saboteur_game_id uuid, p_objective_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
  v_obj  saboteur_objectives;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_participant_for_player(p_player_token, p_saboteur_game_id);

  select * into v_obj from saboteur_objectives where id = p_objective_id and assigned_participant_id = v_part.id;
  if not found then
    raise exception 'Fant ikke målet';
  end if;

  if v_obj.status = 'assigned' then
    if v_obj.expires_at is not null and now() > v_obj.expires_at then
      raise exception 'Fristen for dette målet er utløpt';
    end if;
    update saboteur_objectives set status = 'claimed', claimed_at = now() where id = v_obj.id;
    return json_build_object('ok', true, 'status', 'claimed');
  end if;

  -- Idempotent: already claimed/approved/rejected — return current status, no-op.
  return json_build_object('ok', true, 'status', v_obj.status);
end $$;

create or replace function claim_saboteur_task(p_player_token uuid, p_saboteur_game_id uuid, p_task_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
  v_task saboteur_tasks;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_participant_for_player(p_player_token, p_saboteur_game_id);

  select * into v_task from saboteur_tasks where id = p_task_id and assigned_participant_id = v_part.id;
  if not found then
    raise exception 'Fant ikke oppgaven';
  end if;

  if v_task.status = 'assigned' then
    update saboteur_tasks set status = 'claimed', claimed_at = now() where id = v_task.id;
    return json_build_object('ok', true, 'status', 'claimed');
  end if;

  return json_build_object('ok', true, 'status', v_task.status);
end $$;

-- ----------------------------------------------------------------------------
-- 6) EXECUTE-RETTIGHETER (explicit grants, matching this schema's convention
--    of granting broadly to anon+authenticated — the secret token is what
--    actually gates access, not the Postgres role)
-- ----------------------------------------------------------------------------

grant execute on function host_create_saboteur_game(uuid, boolean) to anon, authenticated;
grant execute on function host_list_eligible_participants(uuid, uuid) to anon, authenticated;
grant execute on function host_set_participants(uuid, uuid, jsonb) to anon, authenticated;
grant execute on function host_set_participant_active(uuid, uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_set_know_each_other(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_set_show_leaderboard(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_set_saboteur_status(uuid, uuid, text) to anon, authenticated;
grant execute on function host_end_saboteur_game(uuid, uuid) to anon, authenticated;
grant execute on function host_archive_saboteur_game(uuid, uuid) to anon, authenticated;
grant execute on function host_upsert_objective(uuid, uuid, uuid, uuid, text, text, int, timestamptz) to anon, authenticated;
grant execute on function host_decide_objective_claim(uuid, uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_upsert_task(uuid, uuid, uuid, uuid, text, text, text, text) to anon, authenticated;
grant execute on function host_decide_task_claim(uuid, uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_open_voting_round(uuid, uuid) to anon, authenticated;
grant execute on function host_close_voting_round(uuid, uuid, uuid) to anon, authenticated;
grant execute on function host_reveal_voting_round(uuid, uuid, uuid) to anon, authenticated;
grant execute on function host_get_saboteur_game(uuid, uuid) to anon, authenticated;
grant execute on function host_get_saboteur_audit(uuid, uuid) to anon, authenticated;

grant execute on function get_my_saboteur_brief(uuid, uuid) to anon, authenticated;
grant execute on function get_my_saboteur_vote_status(uuid, uuid) to anon, authenticated;
grant execute on function get_saboteur_ballot_targets(uuid, uuid) to anon, authenticated;
grant execute on function cast_saboteur_ballot(uuid, uuid, uuid, uuid) to anon, authenticated;
grant execute on function claim_saboteur_objective(uuid, uuid, uuid) to anon, authenticated;
grant execute on function claim_saboteur_task(uuid, uuid, uuid) to anon, authenticated;
