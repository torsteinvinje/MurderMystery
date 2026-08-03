-- ============================================================================
-- MIGRASJON 00013 — Skjult agenda: unike navn, personlig PIN, regi og beskjeder
--
-- Fire ting, alle bedt om etter første ekte testrunde:
--
-- 1) UNIKE NAVN per spill. To «Marius» i samme spill gjør vertskontrollen
--    umulig å lese. Håndheves både med en unik indeks (den ekte garantien,
--    også når to melder seg på samtidig) og med en vennlig feilmelding.
--
-- 2) PERSONLIG PIN. Spillernøkkelen ligger i nettleseren; tømmer en gjest
--    fanen, eller trykker feil, er rollen borte. Nå får hver deltaker en
--    firesifret kode som verten ser i deltakerlista. Gjesten kommer tilbake
--    med spillkode + navn + PIN, og får samme deltaker igjen — ingen ny rad,
--    ingen tapt rolle.
--
-- 3) REGI (phase). Samme grep som mordmysteriet: status styrer hva som er
--    LOV (utkast/aktiv/avstemning), mens phase forteller hvor i kvelden man
--    er («Rollene deles ut», «Nå stemmer vi»). Teksten bor i klienten; her
--    lagres bare hvilken fase som er valgt.
--
-- 4) BESKJEDER. Verten kan publisere korte meldinger til ALLE deltakere,
--    uavhengig av rolle — i motsetning til hint, som er knyttet til en
--    oppgave og kun går til utvalgte Lojale.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) UNIKE NAVN + PERSONLIG PIN
-- ----------------------------------------------------------------------------

alter table saboteur_participants add column if not exists pin text;

-- Fyll inn PIN for eventuelle deltakere som ble med før denne migrasjonen.
do $$
declare
  r record;
  v_pin text;
begin
  for r in select id, saboteur_game_id from saboteur_participants where pin is null
  loop
    loop
      v_pin := lpad(floor(random() * 10000)::int::text, 4, '0');
      exit when not exists (
        select 1 from saboteur_participants
        where saboteur_game_id = r.saboteur_game_id and pin = v_pin
      );
    end loop;
    update saboteur_participants set pin = v_pin where id = r.id;
  end loop;
end $$;

alter table saboteur_participants alter column pin set not null;

-- Navn er unike per spill, uavhengig av store/små bokstaver. Indeksen er den
-- reelle garantien; RPC-en under gir den pene feilmeldingen.
create unique index if not exists saboteur_participants_unique_name
  on saboteur_participants (saboteur_game_id, lower(display_name));

create unique index if not exists saboteur_participants_unique_pin
  on saboteur_participants (saboteur_game_id, pin);

-- ----------------------------------------------------------------------------
-- 2) REGI (phase)
-- ----------------------------------------------------------------------------

alter table saboteur_games add column if not exists phase text not null default 'lobby';

-- ----------------------------------------------------------------------------
-- 3) BESKJEDER TIL ALLE
-- ----------------------------------------------------------------------------

create table if not exists saboteur_announcements (
  id               uuid primary key default gen_random_uuid(),
  saboteur_game_id uuid not null references saboteur_games (id) on delete cascade,
  body             text not null,
  created_at       timestamptz not null default now()
);
create index if not exists saboteur_announcements_game_idx
  on saboteur_announcements (saboteur_game_id, created_at desc);

alter table saboteur_announcements enable row level security;
revoke all on saboteur_announcements from anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4) OPPDATERTE / NYE RPC-ER
-- ----------------------------------------------------------------------------

-- Bli med: krever nå unikt navn, og returnerer deltakerens PIN så gjesten
-- kan skrive den ned med én gang.
create or replace function join_saboteur_game(p_code text, p_name text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_part saboteur_participants;
  v_name text := trim(coalesce(p_name, ''));
  v_code text := upper(trim(coalesce(p_code, '')));
  v_pin  text;
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
    raise exception 'Spillet er allerede i gang — har du vært med før, bruk «Kom tilbake» med navn og PIN';
  end if;

  if exists (
    select 1 from saboteur_participants
    where saboteur_game_id = v_game.id and lower(display_name) = lower(v_name)
  ) then
    raise exception 'Navnet «%» er allerede i bruk i dette spillet — velg et annet', v_name;
  end if;

  loop
    v_pin := lpad(floor(random() * 10000)::int::text, 4, '0');
    exit when not exists (
      select 1 from saboteur_participants where saboteur_game_id = v_game.id and pin = v_pin
    );
  end loop;

  begin
    insert into saboteur_participants (saboteur_game_id, display_name, pin)
    values (v_game.id, v_name, v_pin)
    returning * into v_part;
  exception when unique_violation then
    -- To personer traff samme navn i samme sekund.
    raise exception 'Navnet «%» ble akkurat tatt — velg et annet', v_name;
  end;

  perform _saboteur_audit(v_game.id, 'participant_joined', jsonb_build_object('participant_id', v_part.id));

  return json_build_object(
    'player_token', v_part.player_token,
    'participant_id', v_part.id,
    'saboteur_game_id', v_game.id,
    'code', v_game.code,
    'title', v_game.title,
    'pin', v_part.pin
  );
end $$;

-- Kom tilbake: gjenopprett tilgang med spillkode + navn + PIN. Gir samme
-- deltakerrad tilbake, så rolle, mål, oppgaver og hint er i behold.
-- Virker i alle statuser unntatt arkivert — det er hele poenget: en gjest
-- som mister tilgangen midt i spillet må kunne komme inn igjen.
create or replace function rejoin_saboteur_game(p_code text, p_name text, p_pin text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_part saboteur_participants;
  v_name text := trim(coalesce(p_name, ''));
  v_code text := upper(trim(coalesce(p_code, '')));
  v_pin  text := trim(coalesce(p_pin, ''));
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;

  select * into v_game from saboteur_games where code = v_code and status <> 'archived';
  if not found then
    raise exception 'Fant ingen spill med koden «%»', v_code;
  end if;

  select * into v_part from saboteur_participants
  where saboteur_game_id = v_game.id
    and lower(display_name) = lower(v_name)
    and pin = v_pin;

  -- Bevisst vag melding: ikke røp om det var navnet eller PIN-en som var feil.
  if not found then
    raise exception 'Fant ingen deltaker med det navnet og den PIN-en';
  end if;

  return json_build_object(
    'player_token', v_part.player_token,
    'participant_id', v_part.id,
    'saboteur_game_id', v_game.id,
    'code', v_game.code,
    'title', v_game.title,
    'pin', v_part.pin
  );
end $$;

-- Regi: hvilken del av kvelden vi er i. Fritt valgbart av verten, uavhengig
-- av status — de to styrer hver sin ting (status = hva som er lov, phase =
-- hvor i opplegget vi er).
create or replace function host_set_saboteur_phase(p_host_token uuid, p_phase text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_phase text := trim(coalesce(p_phase, ''));
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_phase not in ('lobby', 'roller', 'oppdrag', 'avstemning', 'avsloring') then
    raise exception 'Ukjent fase: %', v_phase;
  end if;

  update saboteur_games set phase = v_phase, updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'phase_change', jsonb_build_object('phase', v_phase));
  return json_build_object('ok', true, 'phase', v_phase);
end $$;

-- Beskjed til alle deltakere (uavhengig av rolle).
create or replace function host_publish_announcement(p_host_token uuid, p_body text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_body text := trim(coalesce(p_body, ''));
  v_id   uuid;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_body = '' then
    raise exception 'Beskjeden kan ikke være tom';
  end if;
  if length(v_body) > 500 then
    raise exception 'Beskjeden er for lang (maks 500 tegn)';
  end if;

  insert into saboteur_announcements (saboteur_game_id, body)
  values (v_game.id, v_body)
  returning id into v_id;

  perform _saboteur_audit(v_game.id, 'announcement_published', jsonb_build_object('announcement_id', v_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_delete_announcement(p_host_token uuid, p_announcement_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  delete from saboteur_announcements
  where id = p_announcement_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent beskjed';
  end if;

  perform _saboteur_audit(v_game.id, 'announcement_deleted', jsonb_build_object('announcement_id', p_announcement_id));
  return json_build_object('ok', true);
end $$;

-- Vertsvisningen: nå med phase, deltakernes PIN og beskjeder.
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
    'phase', v_game.phase,
    'know_each_other', v_game.know_each_other, 'show_leaderboard', v_game.show_leaderboard,
    'created_at', v_game.created_at,

    'participants', (
      select coalesce(json_agg(json_build_object(
        'id', sp.id, 'display_name', sp.display_name, 'role', sp.role, 'active', sp.active,
        'pin', sp.pin,
        'points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = sp.id)
      ) order by sp.joined_at), '[]'::json)
      from saboteur_participants sp where sp.saboteur_game_id = v_game.id
    ),

    'announcements', (
      select coalesce(json_agg(json_build_object(
        'id', a.id, 'body', a.body, 'created_at', a.created_at
      ) order by a.created_at desc), '[]'::json)
      from saboteur_announcements a where a.saboteur_game_id = v_game.id
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

-- Spillerens kort: nå med phase, egen PIN og beskjedene fra verten.
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
    'status', v_game.status, 'phase', v_game.phase,
    'my_name', v_part.display_name, 'my_role', v_part.role, 'my_active', v_part.active,
    'my_pin', v_part.pin,
    'participant_count', (select count(*) from saboteur_participants where saboteur_game_id = v_game.id),

    'announcements', (
      select coalesce(json_agg(json_build_object(
        'id', a.id, 'body', a.body, 'created_at', a.created_at
      ) order by a.created_at desc), '[]'::json)
      from saboteur_announcements a where a.saboteur_game_id = v_game.id
    ),

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

grant execute on function rejoin_saboteur_game(text, text, text) to anon, authenticated;
grant execute on function host_set_saboteur_phase(uuid, text) to anon, authenticated;
grant execute on function host_publish_announcement(uuid, text) to anon, authenticated;
grant execute on function host_delete_announcement(uuid, uuid) to anon, authenticated;
