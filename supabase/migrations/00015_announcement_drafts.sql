-- ============================================================================
-- MIGRASJON 00015 — Beskjeder: utkast, redigering og publisering
--
-- Før kunne verten bare sende en beskjed og slette den igjen. Nå har
-- beskjeder en livssyklus, slik at man kan forberede kvelden i ro og mak:
--
--   skriv (utkast)  ->  rediger så mye du vil  ->  publiser  ->  evt. avpubliser
--                                                            ->  evt. slett
--
-- DEN VIKTIGE REGELEN: et utkast er KUN synlig for verten. get_my_saboteur_brief
-- filtrerer på published, så en halvferdig beskjed aldri kan lekke ut til
-- deltakerne før verten faktisk trykker publiser.
--
-- Migrering av eksisterende data: beskjeder laget før denne migrasjonen var
-- synlige i det øyeblikket de ble laget. Kolonnen får derfor default TRUE i
-- selve ALTER-en (så gamle rader forblir publisert), og deretter settes
-- default til FALSE for nye rader (som nå starter som utkast).
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

alter table saboteur_announcements add column if not exists published boolean not null default true;
alter table saboteur_announcements alter column published set default false;
alter table saboteur_announcements add column if not exists published_at timestamptz;

update saboteur_announcements
   set published_at = created_at
 where published and published_at is null;

-- Den gamle «lag og send i én operasjon» erstattes av upsert + publiser.
drop function if exists host_publish_announcement(uuid, text);

-- Opprett et utkast (p_announcement_id = null) eller rediger en eksisterende
-- beskjed. Redigering virker også etter publisering — teksten oppdateres da
-- for alle med én gang, som er det man vil når man oppdager en skrivefeil.
create or replace function host_upsert_announcement(
  p_host_token uuid, p_announcement_id uuid default null, p_body text default null
)
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

  if p_announcement_id is null then
    insert into saboteur_announcements (saboteur_game_id, body)
    values (v_game.id, v_body)
    returning id into v_id;
    perform _saboteur_audit(v_game.id, 'announcement_drafted', jsonb_build_object('announcement_id', v_id));
  else
    update saboteur_announcements set body = v_body
    where id = p_announcement_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent beskjed';
    end if;
    v_id := p_announcement_id;
    perform _saboteur_audit(v_game.id, 'announcement_edited', jsonb_build_object('announcement_id', v_id));
  end if;

  return json_build_object('ok', true, 'id', v_id);
end $$;

-- Publiser eller trekk tilbake. Idempotent: å publisere noe som allerede er
-- publisert endrer ingenting (og flytter ikke publiseringstidspunktet).
create or replace function host_set_announcement_published(
  p_host_token uuid, p_announcement_id uuid, p_published boolean
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_pub  boolean := coalesce(p_published, false);
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  update saboteur_announcements
     set published    = v_pub,
         published_at = case when v_pub then coalesce(published_at, now()) else null end
   where id = p_announcement_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent beskjed';
  end if;

  perform _saboteur_audit(v_game.id,
    case when v_pub then 'announcement_published' else 'announcement_unpublished' end,
    jsonb_build_object('announcement_id', p_announcement_id));
  return json_build_object('ok', true, 'published', v_pub);
end $$;

-- Vertsvisningen: nå med publiseringsstatus, så utkast kan skilles fra sendte.
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

    -- Verten ser BÅDE utkast og publiserte; deltakerne kun publiserte.
    'announcements', (
      select coalesce(json_agg(json_build_object(
        'id', a.id, 'body', a.body, 'published', a.published,
        'published_at', a.published_at, 'created_at', a.created_at
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

-- Spillerens kort: SER KUN PUBLISERTE BESKJEDER. Dette er hele poenget med
-- utkast — en beskjed under arbeid skal aldri nå deltakerne.
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
        'id', a.id, 'body', a.body, 'created_at', coalesce(a.published_at, a.created_at)
      ) order by coalesce(a.published_at, a.created_at) desc), '[]'::json)
      from saboteur_announcements a
      where a.saboteur_game_id = v_game.id and a.published
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

grant execute on function host_upsert_announcement(uuid, uuid, text) to anon, authenticated;
grant execute on function host_set_announcement_published(uuid, uuid, boolean) to anon, authenticated;
