-- ============================================================================
-- MIGRASJON 00011 — Skjult agenda blir et FRITTSTÅENDE spill
--
-- Erstatter modellen fra 00009/00010, der Skjult agenda levde inni en
-- eksisterende mordmysterie-fest (saboteur_games.game_id -> games.id, og
-- deltakerne var players-rader). Nå er Skjult agenda sitt eget spill med
-- sin egen firetegns kode, sin egen vertsnøkkel og sine egne spillere.
--
-- HVA DET BETYR I PRAKSIS:
--   Før:  vert starter mordmysterium -> gjester blir med -> vert åpner en
--         «Skjult agenda»-fane inni den festen.
--   Nå:   hvem som helst starter et Skjult agenda-spill på /skjult.html og
--         får en egen kode -> gjester blir med med DEN koden. Mordmysteriet
--         er ikke involvert i det hele tatt.
--
-- ADVARSEL OM DATA: denne migrasjonen sletter alle Skjult agenda-tabeller
-- fra 00009/00010 og bygger dem opp på nytt. Det er trygt her fordi
-- funksjonen aldri har vært skrudd på (app_feature_flags-raden har stått
-- på false siden den ble laget, og hver eneste RPC nekter når den er av) —
-- så det finnes ingen ekte spilldata å miste. Mordmysteriet sine tabeller
-- (games/players/suspects/polaroids/mysteries/profiles) røres ALDRI.
--
-- SIKKERHETSMODELLEN ER UENDRET og følger resten av skjemaet:
--   - Funksjonsflagget app_feature_flags('SABOTEUR_GAME_ENABLED') sjekkes
--     som FØRSTE setning i hver eneste RPC, før noen token slås opp. Av som
--     standard. Et gjettet API-kall kan ikke slå på eller utforske noe.
--   - RLS på alle tabeller, ZERO policies, alle grants trukket tilbake fra
--     anon/authenticated. All tilgang via SECURITY DEFINER-RPC-er som
--     bygger minimale, mottaker-spesifikke JSON-svar for hånd.
--   - Nye hjelpere _saboteur_host/_saboteur_me speiler _host_game/_player:
--     tokenet identifiserer BÅDE hvem du er og hvilket spill du er i, så
--     det finnes ingen spill-id å tukle med utenfra.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) RYDD BORT DEN GAMLE, FESTBUNDNE MODELLEN (00009 + 00010)
-- ----------------------------------------------------------------------------

drop function if exists claim_saboteur_task(uuid, uuid, uuid);
drop function if exists claim_saboteur_objective(uuid, uuid, uuid);
drop function if exists cast_saboteur_ballot(uuid, uuid, uuid, uuid);
drop function if exists get_saboteur_ballot_targets(uuid, uuid);
drop function if exists get_my_saboteur_vote_status(uuid, uuid);
drop function if exists get_my_saboteur_brief(uuid, uuid);
drop function if exists get_my_saboteur_game_id(uuid);
drop function if exists host_get_saboteur_audit(uuid, uuid);
drop function if exists host_get_saboteur_game(uuid, uuid);
drop function if exists host_reveal_voting_round(uuid, uuid, uuid);
drop function if exists host_close_voting_round(uuid, uuid, uuid);
drop function if exists host_open_voting_round(uuid, uuid);
drop function if exists host_decide_task_claim(uuid, uuid, uuid, boolean);
drop function if exists host_upsert_task(uuid, uuid, uuid, uuid, text, text, text, text);
drop function if exists host_decide_objective_claim(uuid, uuid, uuid, boolean);
drop function if exists host_upsert_objective(uuid, uuid, uuid, uuid, text, text, int, timestamptz);
drop function if exists host_archive_saboteur_game(uuid, uuid);
drop function if exists host_end_saboteur_game(uuid, uuid);
drop function if exists host_set_saboteur_status(uuid, uuid, text);
drop function if exists host_set_show_leaderboard(uuid, uuid, boolean);
drop function if exists host_set_know_each_other(uuid, uuid, boolean);
drop function if exists host_set_participant_active(uuid, uuid, uuid, boolean);
drop function if exists host_set_participants(uuid, uuid, jsonb);
drop function if exists host_list_eligible_participants(uuid, uuid);
drop function if exists host_create_saboteur_game(uuid, boolean);
drop function if exists _saboteur_apply_transition(uuid, text);
drop function if exists _saboteur_audit(uuid, text, jsonb);
drop function if exists _saboteur_participant_for_player(uuid, uuid);
drop function if exists _saboteur_game_for_host(uuid, uuid);

drop table if exists saboteur_audit_log;
drop table if exists saboteur_points_ledger;
drop table if exists saboteur_ballots;
drop table if exists saboteur_voting_rounds;
drop table if exists saboteur_hint_releases;
drop table if exists saboteur_tasks;
drop table if exists saboteur_objectives;
drop table if exists saboteur_participants;
drop table if exists saboteur_games;

-- ----------------------------------------------------------------------------
-- 1) FUNKSJONSFLAGG (beholdes; av som standard)
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

create or replace function _saboteur_enabled()
returns boolean
language sql security definer set search_path = public
as $$
  select coalesce((select enabled from app_feature_flags where key = 'SABOTEUR_GAME_ENABLED'), false);
$$;

revoke execute on function _saboteur_enabled() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2) TABELLER — nå frittstående
-- ----------------------------------------------------------------------------

-- Et Skjult agenda-spill. Har sin egen kode og sin egen vertsnøkkel, akkurat
-- som games-tabellen har for mordmysteriet — men helt uavhengig av den.
create table saboteur_games (
  id               uuid primary key default gen_random_uuid(),
  code             text not null unique,                       -- koden gjestene taster inn
  host_token       uuid not null default gen_random_uuid(),    -- hemmelig vertsnøkkel
  title            text not null default 'Skjult agenda',
  status           text not null default 'draft'
                   check (status in ('draft','active','voting','paused','ended','archived')),
  know_each_other  boolean not null default false,
  show_leaderboard boolean not null default false,
  -- Valgfri kobling til en innlogget konto (samme mønster som games.owner_id).
  -- Null for anonyme verter, som er den vanlige måten å bruke appen på.
  owner_id         uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index saboteur_games_owner_idx on saboteur_games (owner_id);

-- En deltaker. Slår sammen det som før var «players-rad» + «participant-rad»:
-- deltakeren har nå sin egen hemmelige player_token og sitt eget visningsnavn.
-- role er NULL til verten deler ut roller (før var rollen påkrevd fra start).
create table saboteur_participants (
  id               uuid primary key default gen_random_uuid(),
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  player_token     uuid not null unique default gen_random_uuid(), -- hemmelig spillernøkkel
  display_name     text not null,
  role             text check (role is null or role in ('SABOTEUR','LOYAL')),
  active           boolean not null default true,
  joined_at        timestamptz not null default now()
);
create index saboteur_participants_game_idx on saboteur_participants (saboteur_game_id);

create table saboteur_objectives (
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
create index saboteur_objectives_game_idx on saboteur_objectives (saboteur_game_id);
create index saboteur_objectives_participant_idx on saboteur_objectives (assigned_participant_id);

create table saboteur_tasks (
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
create index saboteur_tasks_game_idx on saboteur_tasks (saboteur_game_id);
create index saboteur_tasks_participant_idx on saboteur_tasks (assigned_participant_id);

create table saboteur_hint_releases (
  id                         uuid primary key default gen_random_uuid(),
  task_id                    uuid not null references saboteur_tasks (id) on delete cascade,
  released_to_participant_id uuid not null references saboteur_participants (id) on delete cascade,
  created_at                 timestamptz not null default now(),
  unique (task_id, released_to_participant_id)   -- idempotent utdeling
);
create index saboteur_hint_releases_participant_idx on saboteur_hint_releases (released_to_participant_id);

create table saboteur_voting_rounds (
  id               uuid primary key default gen_random_uuid(),
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  status           text not null default 'open' check (status in ('open','closed','revealed')),
  opened_at        timestamptz not null default now(),
  closed_at        timestamptz,
  revealed_at      timestamptz
);
create unique index saboteur_voting_rounds_one_open
  on saboteur_voting_rounds (saboteur_game_id) where status = 'open';
create index saboteur_voting_rounds_game_idx on saboteur_voting_rounds (saboteur_game_id);

create table saboteur_ballots (
  id                    uuid primary key default gen_random_uuid(),
  voting_round_id       uuid not null references saboteur_voting_rounds (id) on delete cascade,
  voter_participant_id  uuid not null references saboteur_participants (id) on delete cascade,
  target_participant_id uuid not null references saboteur_participants (id) on delete cascade,
  created_at            timestamptz not null default now(),
  -- Én stemme per deltaker per runde, garantert av databasen selv.
  unique (voting_round_id, voter_participant_id)
);
create index saboteur_ballots_round_idx on saboteur_ballots (voting_round_id);
create index saboteur_ballots_target_idx on saboteur_ballots (target_participant_id);

create table saboteur_points_ledger (
  id             uuid primary key default gen_random_uuid(),
  participant_id uuid not null references saboteur_participants (id) on delete cascade,
  source_type    text not null check (source_type in ('objective','adjustment')),
  source_id      uuid,
  points         int not null,
  created_at     timestamptz not null default now()
);
-- Idempotens: samme godkjenning kan aldri gi poeng to ganger.
create unique index saboteur_points_ledger_idempotent
  on saboteur_points_ledger (source_type, source_id) where source_id is not null;
create index saboteur_points_ledger_participant_idx on saboteur_points_ledger (participant_id);

create table saboteur_audit_log (
  id               bigint generated always as identity primary key,
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  actor            text not null default 'host',
  action           text not null,
  payload          jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now()
);
create index saboteur_audit_log_game_idx on saboteur_audit_log (saboteur_game_id, id);

-- ----------------------------------------------------------------------------
-- 3) RLS: på, uten policies. All tilgang via RPC-ene under.
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
-- 4) INTERNE HJELPERE (speiler _host_game / _player)
-- ----------------------------------------------------------------------------

-- Vertsnøkkelen identifiserer både verten OG spillet. Det finnes altså ingen
-- spill-id en angriper kan bytte ut for å nå et annet spill.
create or replace function _saboteur_host(p_host_token uuid)
returns saboteur_games
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if p_host_token is null then
    raise exception 'Mangler vertsnøkkel';
  end if;
  select * into v_game from saboteur_games where host_token = p_host_token;
  if not found then
    raise exception 'Ugyldig vertsnøkkel — fant ikke spillet';
  end if;
  return v_game;
end $$;

revoke execute on function _saboteur_host(uuid) from public, anon, authenticated;

-- Samme for en spiller: spillernøkkelen sier både hvem du er og hvilket spill.
create or replace function _saboteur_me(p_player_token uuid)
returns saboteur_participants
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
begin
  if p_player_token is null then
    raise exception 'Mangler spillernøkkel';
  end if;
  select * into v_part from saboteur_participants where player_token = p_player_token;
  if not found then
    raise exception 'Ugyldig spillernøkkel — fant ikke deltakeren';
  end if;
  return v_part;
end $$;

revoke execute on function _saboteur_me(uuid) from public, anon, authenticated;

create or replace function _saboteur_audit(p_saboteur_game_id uuid, p_action text, p_payload jsonb default '{}'::jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into saboteur_audit_log (saboteur_game_id, actor, action, payload)
  values (p_saboteur_game_id, 'host', p_action, p_payload);
end $$;

revoke execute on function _saboteur_audit(uuid, text, jsonb) from public, anon, authenticated;

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
    raise exception 'Lukk avstemningsrunden først';
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

  -- Et spillbart spill trenger minst én Sabotør og én Lojal.
  if v_game.status = 'draft' and p_new_status = 'active' then
    if (select count(distinct role) from saboteur_participants
        where saboteur_game_id = p_saboteur_game_id and active and role is not null) < 2 then
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
-- 5) OPPRETT OG BLI MED (frittstående — ingen mordmysterie-fest involvert)
-- ----------------------------------------------------------------------------

-- Hvem som helst kan starte et spill, akkurat som create_game for mordmysteriet.
create or replace function create_saboteur_game(p_title text default null, p_know_each_other boolean default false)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_code  text;
  v_chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- uten lett forvekslbare tegn
  v_title text := nullif(trim(coalesce(p_title, '')), '');
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;

  if v_title is not null and length(v_title) > 80 then
    raise exception 'Tittelen er for lang (maks 80 tegn)';
  end if;

  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from saboteur_games where code = v_code);
  end loop;

  insert into saboteur_games (code, title, know_each_other, owner_id)
  values (v_code, coalesce(v_title, 'Skjult agenda'), coalesce(p_know_each_other, false), auth.uid())
  returning * into v_game;

  perform _saboteur_audit(v_game.id, 'game_created', jsonb_build_object('know_each_other', v_game.know_each_other));

  return json_build_object(
    'saboteur_game_id', v_game.id,
    'code', v_game.code,
    'host_token', v_game.host_token,
    'title', v_game.title,
    'status', v_game.status
  );
end $$;

-- En gjest blir med med koden. Får sin egen hemmelige spillernøkkel.
create or replace function join_saboteur_game(p_code text, p_name text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_part saboteur_participants;
  v_name text := trim(coalesce(p_name, ''));
  v_code text := upper(trim(coalesce(p_code, '')));
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;

  if v_name = '' then
    raise exception 'Du må skrive inn et navn';
  end if;
  if length(v_name) > 40 then
    raise exception 'Navnet er for langt (maks 40 tegn)';
  end if;

  select * into v_game from saboteur_games where code = v_code;
  if not found then
    raise exception 'Fant ingen spill med koden «%»', v_code;
  end if;
  if v_game.status <> 'draft' then
    raise exception 'Spillet er allerede i gang — be verten åpne for nye deltakere';
  end if;

  insert into saboteur_participants (saboteur_game_id, display_name)
  values (v_game.id, v_name)
  returning * into v_part;

  perform _saboteur_audit(v_game.id, 'participant_joined', jsonb_build_object('participant_id', v_part.id));

  return json_build_object(
    'player_token', v_part.player_token,
    'participant_id', v_part.id,
    'saboteur_game_id', v_game.id,
    'code', v_game.code,
    'title', v_game.title
  );
end $$;

-- ----------------------------------------------------------------------------
-- 6) RPC: VERTSKONTROLL (host_token identifiserer spillet — ingen spill-id inn)
-- ----------------------------------------------------------------------------

create or replace function host_get_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_game.id order by opened_at desc limit 1;

  return json_build_object(
    'id', v_game.id, 'code', v_game.code, 'title', v_game.title, 'status', v_game.status,
    'know_each_other', v_game.know_each_other, 'show_leaderboard', v_game.show_leaderboard,
    'created_at', v_game.created_at,

    'participants', (
      select coalesce(json_agg(json_build_object(
        'id', sp.id, 'display_name', sp.display_name, 'role', sp.role, 'active', sp.active,
        'points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = sp.id)
      ) order by sp.joined_at), '[]'::json)
      from saboteur_participants sp where sp.saboteur_game_id = v_game.id
    ),

    'objectives', (
      select coalesce(json_agg(json_build_object(
        'id', o.id, 'participant_id', o.assigned_participant_id, 'title', o.title,
        'description', o.description, 'points', o.points, 'expires_at', o.expires_at,
        'status', o.status, 'claimed_at', o.claimed_at, 'decided_at', o.decided_at
      ) order by o.created_at), '[]'::json)
      from saboteur_objectives o where o.saboteur_game_id = v_game.id
    ),

    'tasks', (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'participant_id', t.assigned_participant_id, 'title', t.title,
        'description', t.description, 'hint_text', t.hint_text, 'hint_audience', t.hint_audience,
        'status', t.status, 'claimed_at', t.claimed_at, 'decided_at', t.decided_at
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t where t.saboteur_game_id = v_game.id
    ),

    -- Stemmene er hemmelige — også for verten — til runden er BÅDE lukket og
    -- eksplisitt avslørt. Underveis vises kun antall avgitte stemmer.
    'current_round', case when v_round.id is null then null else json_build_object(
      'id', v_round.id, 'status', v_round.status,
      'opened_at', v_round.opened_at, 'closed_at', v_round.closed_at, 'revealed_at', v_round.revealed_at,
      'ballot_count', (select count(*) from saboteur_ballots b where b.voting_round_id = v_round.id),
      'tally', case when v_round.status = 'revealed' then (
        select coalesce(json_agg(json_build_object(
          'participant_id', x.target_participant_id, 'display_name', sp.display_name, 'votes', x.votes
        ) order by x.votes desc), '[]'::json)
        from (
          select target_participant_id, count(*) as votes
          from saboteur_ballots where voting_round_id = v_round.id
          group by target_participant_id
        ) x
        join saboteur_participants sp on sp.id = x.target_participant_id
      ) else null end
    ) end
  );
end $$;

create or replace function host_set_participant_role(p_host_token uuid, p_participant_id uuid, p_role text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_role text := nullif(trim(coalesce(p_role, '')), '');
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status <> 'draft' then
    raise exception 'Roller kan bare endres mens spillet er i utkast';
  end if;
  if v_role is not null and v_role not in ('SABOTEUR', 'LOYAL') then
    raise exception 'Ukjent rolle: %', v_role;
  end if;

  update saboteur_participants set role = v_role
  where id = p_participant_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent deltaker';
  end if;

  perform _saboteur_audit(v_game.id, 'set_role',
    jsonb_build_object('participant_id', p_participant_id, 'role', v_role));
  return json_build_object('ok', true);
end $$;

-- Del ut roller tilfeldig. p_saboteur_count sabotører, resten lojale.
create or replace function host_auto_assign_roles(p_host_token uuid, p_saboteur_count int default 1)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_total int;
  v_count int := greatest(coalesce(p_saboteur_count, 1), 1);
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status <> 'draft' then
    raise exception 'Roller kan bare endres mens spillet er i utkast';
  end if;

  select count(*) into v_total from saboteur_participants
  where saboteur_game_id = v_game.id and active;
  if v_total < 2 then
    raise exception 'Trenger minst to deltakere for å dele ut roller';
  end if;
  if v_count >= v_total then
    raise exception 'Det må være minst én Lojal igjen';
  end if;

  update saboteur_participants set role = 'LOYAL'
  where saboteur_game_id = v_game.id and active;

  update saboteur_participants set role = 'SABOTEUR'
  where id in (
    select id from saboteur_participants
    where saboteur_game_id = v_game.id and active
    order by random() limit v_count
  );

  perform _saboteur_audit(v_game.id, 'auto_assign_roles', jsonb_build_object('saboteur_count', v_count));
  return json_build_object('ok', true, 'saboteurs', v_count, 'loyals', v_total - v_count);
end $$;

create or replace function host_set_participant_active(p_host_token uuid, p_participant_id uuid, p_active boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  update saboteur_participants set active = coalesce(p_active, true)
  where id = p_participant_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent deltaker';
  end if;

  perform _saboteur_audit(v_game.id, 'set_participant_active',
    jsonb_build_object('participant_id', p_participant_id, 'active', p_active));
  return json_build_object('ok', true);
end $$;

create or replace function host_remove_participant(p_host_token uuid, p_participant_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status <> 'draft' then
    raise exception 'Deltakere kan bare fjernes mens spillet er i utkast';
  end if;

  delete from saboteur_participants where id = p_participant_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent deltaker';
  end if;

  perform _saboteur_audit(v_game.id, 'remove_participant', jsonb_build_object('participant_id', p_participant_id));
  return json_build_object('ok', true);
end $$;

create or replace function host_set_know_each_other(p_host_token uuid, p_enabled boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;

  update saboteur_games set know_each_other = coalesce(p_enabled, false), updated_at = now()
  where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'set_know_each_other', jsonb_build_object('enabled', p_enabled));
  return json_build_object('ok', true);
end $$;

create or replace function host_set_show_leaderboard(p_host_token uuid, p_enabled boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  update saboteur_games set show_leaderboard = coalesce(p_enabled, false), updated_at = now()
  where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'set_show_leaderboard', jsonb_build_object('enabled', p_enabled));
  return json_build_object('ok', true);
end $$;

create or replace function host_set_saboteur_status(p_host_token uuid, p_status text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  perform _saboteur_apply_transition(v_game.id, p_status);
  return json_build_object('ok', true, 'status', p_status);
end $$;

create or replace function host_end_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  perform _saboteur_apply_transition(v_game.id, 'ended');
  return json_build_object('ok', true);
end $$;

create or replace function host_archive_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  perform _saboteur_apply_transition(v_game.id, 'archived');
  return json_build_object('ok', true);
end $$;

create or replace function host_upsert_objective(
  p_host_token uuid, p_objective_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_points int default 0, p_expires_at timestamptz default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_id    uuid;
  v_title text := trim(coalesce(p_title, ''));
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;

  if p_objective_id is null then
    if v_title = '' then
      raise exception 'Målet trenger en tittel';
    end if;
    perform 1 from saboteur_participants
      where id = p_participant_id and saboteur_game_id = v_game.id and role = 'SABOTEUR';
    if not found then
      raise exception 'Målet må tildeles en Sabotør i dette spillet';
    end if;

    insert into saboteur_objectives (saboteur_game_id, assigned_participant_id, title, description, points, expires_at)
    values (v_game.id, p_participant_id, v_title, coalesce(p_description, ''), coalesce(p_points, 0), p_expires_at)
    returning id into v_id;
  else
    update saboteur_objectives set
      title       = coalesce(nullif(trim(p_title), ''), title),
      description = coalesce(p_description, description),
      points      = coalesce(p_points, points),
      expires_at  = coalesce(p_expires_at, expires_at)
    where id = p_objective_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent mål';
    end if;
    v_id := p_objective_id;
  end if;

  perform _saboteur_audit(v_game.id, 'objective_upsert', jsonb_build_object('objective_id', v_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_decide_objective_claim(p_host_token uuid, p_objective_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_obj      saboteur_objectives;
  v_rowcount int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_obj from saboteur_objectives where id = p_objective_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent mål';
  end if;

  -- Allerede avgjort: idempotent no-op, så gjentatte kall aldri gir poeng på nytt.
  if v_obj.status in ('approved', 'rejected') then
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

  perform _saboteur_audit(v_game.id, 'objective_decided',
    jsonb_build_object('objective_id', v_obj.id, 'approved', p_approve, 'points_awarded', v_rowcount > 0));
  return json_build_object('ok', true,
    'status', case when p_approve then 'approved' else 'rejected' end,
    'points_awarded', v_rowcount > 0);
end $$;

create or replace function host_upsert_task(
  p_host_token uuid, p_task_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_hint_text text default null, p_hint_audience text default 'assignee'
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_id       uuid;
  v_title    text := trim(coalesce(p_title, ''));
  v_audience text := coalesce(p_hint_audience, 'assignee');
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
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
      where id = p_participant_id and saboteur_game_id = v_game.id and role = 'LOYAL';
    if not found then
      raise exception 'Oppgaven må tildeles en Lojal i dette spillet';
    end if;

    insert into saboteur_tasks (saboteur_game_id, assigned_participant_id, title, description, hint_text, hint_audience)
    values (v_game.id, p_participant_id, v_title, coalesce(p_description, ''), coalesce(p_hint_text, ''), v_audience)
    returning id into v_id;
  else
    update saboteur_tasks set
      title         = coalesce(nullif(trim(p_title), ''), title),
      description   = coalesce(p_description, description),
      hint_text     = coalesce(p_hint_text, hint_text),
      hint_audience = coalesce(p_hint_audience, hint_audience)
    where id = p_task_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent oppgave';
    end if;
    v_id := p_task_id;
  end if;

  perform _saboteur_audit(v_game.id, 'task_upsert', jsonb_build_object('task_id', v_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_decide_task_claim(p_host_token uuid, p_task_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_task     saboteur_tasks;
  v_released int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_task from saboteur_tasks where id = p_task_id and saboteur_game_id = v_game.id;
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
      where sp.saboteur_game_id = v_game.id and sp.role = 'LOYAL' and sp.active
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

  perform _saboteur_audit(v_game.id, 'task_decided',
    jsonb_build_object('task_id', v_task.id, 'approved', p_approve, 'hints_released', v_released));
  return json_build_object('ok', true, 'status', case when p_approve then 'approved' else 'rejected' end);
end $$;

create or replace function host_open_voting_round(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status <> 'active' then
    raise exception 'Spillet må være aktivt for å åpne en avstemning';
  end if;

  begin
    insert into saboteur_voting_rounds (saboteur_game_id) values (v_game.id) returning * into v_round;
  exception when unique_violation then
    raise exception 'Det er allerede en åpen avstemningsrunde';
  end;

  update saboteur_games set status = 'voting', updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'voting_opened', jsonb_build_object('round_id', v_round.id));
  return json_build_object('ok', true, 'round_id', v_round.id);
end $$;

create or replace function host_close_voting_round(p_host_token uuid, p_round_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_round from saboteur_voting_rounds where id = p_round_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent avstemningsrunde';
  end if;
  if v_round.status <> 'open' then
    raise exception 'Runden er ikke åpen';
  end if;

  update saboteur_voting_rounds set status = 'closed', closed_at = now() where id = v_round.id;
  update saboteur_games set status = 'active', updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'voting_closed', jsonb_build_object('round_id', v_round.id));
  return json_build_object('ok', true);
end $$;

create or replace function host_reveal_voting_round(p_host_token uuid, p_round_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_round from saboteur_voting_rounds where id = p_round_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent avstemningsrunde';
  end if;
  if v_round.status <> 'closed' then
    raise exception 'Lukk runden før den kan avsløres';
  end if;

  update saboteur_voting_rounds set status = 'revealed', revealed_at = now() where id = v_round.id;
  perform _saboteur_audit(v_game.id, 'voting_revealed', jsonb_build_object('round_id', v_round.id));
  return json_build_object('ok', true);
end $$;

create or replace function host_get_saboteur_audit(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  return (
    select coalesce(json_agg(json_build_object(
      'id', a.id, 'actor', a.actor, 'action', a.action, 'payload', a.payload, 'created_at', a.created_at
    ) order by a.id), '[]'::json)
    from saboteur_audit_log a where a.saboteur_game_id = v_game.id
  );
end $$;

-- ----------------------------------------------------------------------------
-- 7) RPC: SPILLERE (player_token identifiserer både spiller og spill)
--     Returnerer ALDRI andres rolle, mål, oppgaver, hint eller stemmer.
-- ----------------------------------------------------------------------------

create or replace function get_my_saboteur_brief(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);
  select * into v_game from saboteur_games where id = v_part.saboteur_game_id;

  return json_build_object(
    'saboteur_game_id', v_game.id, 'code', v_game.code, 'title', v_game.title,
    'status', v_game.status,
    'my_name', v_part.display_name, 'my_role', v_part.role, 'my_active', v_part.active,
    'participant_count', (select count(*) from saboteur_participants where saboteur_game_id = v_game.id),

    -- Kun hvis verten har slått på «sabotørene kjenner hverandre».
    'fellow_saboteurs', case when v_part.role = 'SABOTEUR' and v_game.know_each_other then (
      select coalesce(json_agg(json_build_object('display_name', sp.display_name)), '[]'::json)
      from saboteur_participants sp
      where sp.saboteur_game_id = v_game.id and sp.role = 'SABOTEUR' and sp.id <> v_part.id
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

    -- Kun rader som eksplisitt er delt ut til MEG.
    'hints', (
      select coalesce(json_agg(json_build_object(
        'task_id', hr.task_id, 'hint_text', t.hint_text, 'released_at', hr.created_at
      ) order by hr.created_at), '[]'::json)
      from saboteur_hint_releases hr join saboteur_tasks t on t.id = hr.task_id
      where hr.released_to_participant_id = v_part.id
    ),

    'reveal', case when v_game.status = 'ended' then json_build_object(
      'participants', (
        select coalesce(json_agg(json_build_object('display_name', sp.display_name, 'role', sp.role)
          order by sp.display_name), '[]'::json)
        from saboteur_participants sp where sp.saboteur_game_id = v_game.id
      ),
      'my_points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = v_part.id),
      'leaderboard', case when v_game.show_leaderboard then (
        select coalesce(json_agg(json_build_object('display_name', x.display_name, 'points', x.points)
          order by x.points desc), '[]'::json)
        from (
          select sp.display_name, coalesce(sum(pl.points), 0) as points
          from saboteur_participants sp
          left join saboteur_points_ledger pl on pl.participant_id = sp.id
          where sp.saboteur_game_id = v_game.id
          group by sp.id, sp.display_name
        ) x
      ) else null end
    ) else null end
  );
end $$;

create or replace function get_my_saboteur_vote_status(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
  v_voted boolean := false;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_part.saboteur_game_id and status = 'open' limit 1;

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

create or replace function get_saboteur_ballot_targets(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_part.saboteur_game_id and status = 'open' limit 1;

  if v_round.id is null or v_part.role <> 'LOYAL' or not v_part.active then
    return '[]'::json;
  end if;

  return (
    select coalesce(json_agg(json_build_object('participant_id', sp.id, 'display_name', sp.display_name)
      order by sp.display_name), '[]'::json)
    from saboteur_participants sp
    where sp.saboteur_game_id = v_part.saboteur_game_id and sp.active
  );
end $$;

create or replace function cast_saboteur_ballot(p_player_token uuid, p_round_id uuid, p_target_participant_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  if v_part.role <> 'LOYAL' or not v_part.active then
    raise exception 'Du kan ikke stemme i denne avstemningen';
  end if;

  select * into v_round from saboteur_voting_rounds
  where id = p_round_id and saboteur_game_id = v_part.saboteur_game_id and status = 'open';
  if not found then
    raise exception 'Avstemningen er ikke åpen';
  end if;

  perform 1 from saboteur_participants
  where id = p_target_participant_id and saboteur_game_id = v_part.saboteur_game_id and active;
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

create or replace function claim_saboteur_objective(p_player_token uuid, p_objective_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
  v_obj  saboteur_objectives;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  select * into v_obj from saboteur_objectives
  where id = p_objective_id and assigned_participant_id = v_part.id;
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

  -- Idempotent: allerede krevd/avgjort — returner gjeldende status, gjør ingenting.
  return json_build_object('ok', true, 'status', v_obj.status);
end $$;

create or replace function claim_saboteur_task(p_player_token uuid, p_task_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
  v_task saboteur_tasks;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  select * into v_task from saboteur_tasks
  where id = p_task_id and assigned_participant_id = v_part.id;
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
-- 8) EXECUTE-RETTIGHETER
-- ----------------------------------------------------------------------------

grant execute on function create_saboteur_game(text, boolean) to anon, authenticated;
grant execute on function join_saboteur_game(text, text) to anon, authenticated;

grant execute on function host_get_saboteur_game(uuid) to anon, authenticated;
grant execute on function host_set_participant_role(uuid, uuid, text) to anon, authenticated;
grant execute on function host_auto_assign_roles(uuid, int) to anon, authenticated;
grant execute on function host_set_participant_active(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_remove_participant(uuid, uuid) to anon, authenticated;
grant execute on function host_set_know_each_other(uuid, boolean) to anon, authenticated;
grant execute on function host_set_show_leaderboard(uuid, boolean) to anon, authenticated;
grant execute on function host_set_saboteur_status(uuid, text) to anon, authenticated;
grant execute on function host_end_saboteur_game(uuid) to anon, authenticated;
grant execute on function host_archive_saboteur_game(uuid) to anon, authenticated;
grant execute on function host_upsert_objective(uuid, uuid, uuid, text, text, int, timestamptz) to anon, authenticated;
grant execute on function host_decide_objective_claim(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_upsert_task(uuid, uuid, uuid, text, text, text, text) to anon, authenticated;
grant execute on function host_decide_task_claim(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_open_voting_round(uuid) to anon, authenticated;
grant execute on function host_close_voting_round(uuid, uuid) to anon, authenticated;
grant execute on function host_reveal_voting_round(uuid, uuid) to anon, authenticated;
grant execute on function host_get_saboteur_audit(uuid) to anon, authenticated;

grant execute on function get_my_saboteur_brief(uuid) to anon, authenticated;
grant execute on function get_my_saboteur_vote_status(uuid) to anon, authenticated;
grant execute on function get_saboteur_ballot_targets(uuid) to anon, authenticated;
grant execute on function cast_saboteur_ballot(uuid, uuid, uuid) to anon, authenticated;
grant execute on function claim_saboteur_objective(uuid, uuid) to anon, authenticated;
grant execute on function claim_saboteur_task(uuid, uuid) to anon, authenticated;
