-- ============================================================================
-- MIGRASJON 00022 — Utkast og publisering for mål og oppgaver
--
-- Samme livssyklus som beskjeder fikk i 00015, nå for sabotørmål og
-- lojaloppgaver:
--
--   skriv (utkast)  ->  rediger fritt  ->  publiser  ->  evt. trekk tilbake
--
-- Poenget er å kunne forberede hele kvelden i ro og mak — legge inn ti mål på
-- forhånd — og så slippe dem ut når det passer, i stedet for at alt dukker
-- opp på spillernes telefoner i det sekundet de opprettes.
--
-- DEN VIKTIGE REGELEN: et utkast er kun synlig for verten.
-- get_my_saboteur_brief filtrerer på published, og claim-funksjonene nekter
-- å kreve noe som ikke er publisert (forsvar i dybden — en spiller skal
-- uansett ikke kjenne id-en til et utkast).
--
-- Migrering av eksisterende data: mål og oppgaver som allerede finnes var
-- synlige i det øyeblikket de ble laget. Kolonnen får derfor default TRUE i
-- selve ALTER-en (så ingenting forsvinner fra en pågående runde), og
-- deretter settes default til FALSE for nye rader.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

alter table saboteur_objectives add column if not exists published boolean not null default true;
alter table saboteur_objectives alter column published set default false;
alter table saboteur_objectives add column if not exists published_at timestamptz;
update saboteur_objectives set published_at = created_at where published and published_at is null;

alter table saboteur_tasks add column if not exists published boolean not null default true;
alter table saboteur_tasks alter column published set default false;
alter table saboteur_tasks add column if not exists published_at timestamptz;
update saboteur_tasks set published_at = created_at where published and published_at is null;

-- ----------------------------------------------------------------------------
-- Publiser / trekk tilbake
-- ----------------------------------------------------------------------------

create or replace function host_set_objective_published(
  p_host_token uuid, p_objective_id uuid, p_published boolean
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

  update saboteur_objectives
     set published    = v_pub,
         published_at = case when v_pub then coalesce(published_at, now()) else null end
   where id = p_objective_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent mål';
  end if;

  perform _saboteur_audit(v_game.id,
    case when v_pub then 'objective_published' else 'objective_unpublished' end,
    jsonb_build_object('objective_id', p_objective_id));
  return json_build_object('ok', true, 'published', v_pub);
end $$;

create or replace function host_set_task_published(
  p_host_token uuid, p_task_id uuid, p_published boolean
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

  update saboteur_tasks
     set published    = v_pub,
         published_at = case when v_pub then coalesce(published_at, now()) else null end
   where id = p_task_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent oppgave';
  end if;

  perform _saboteur_audit(v_game.id,
    case when v_pub then 'task_published' else 'task_unpublished' end,
    jsonb_build_object('task_id', p_task_id));
  return json_build_object('ok', true, 'published', v_pub);
end $$;

-- ----------------------------------------------------------------------------
-- Et utkast kan ikke kreves. Spilleren ser det ikke, så dette er forsvar i
-- dybden mot en gjettet eller gammel id.
-- ----------------------------------------------------------------------------

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
  where id = p_objective_id and assigned_participant_id = v_part.id and published;
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
  where id = p_task_id and assigned_participant_id = v_part.id and published;
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
-- Vertsvisningen: vis publiseringsstatus, så utkast kan skilles fra utsendte
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
    'phase', v_game.phase, 'intro', v_game.intro,
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
        'id', a.id, 'body', a.body, 'published', a.published,
        'published_at', a.published_at, 'created_at', a.created_at
      ) order by a.created_at desc), '[]'::json)
      from saboteur_announcements a where a.saboteur_game_id = v_game.id
    ),

    -- Verten ser BÅDE utkast og publiserte; spillerne kun publiserte.
    'objectives', (
      select coalesce(json_agg(json_build_object(
        'id', o.id, 'participant_id', o.assigned_participant_id, 'title', o.title,
        'description', o.description, 'points', o.points, 'expires_at', o.expires_at,
        'status', o.status, 'claimed_at', o.claimed_at, 'decided_at', o.decided_at,
        'published', o.published, 'published_at', o.published_at
      ) order by o.created_at), '[]'::json)
      from saboteur_objectives o where o.saboteur_game_id = v_game.id
    ),

    'tasks', (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'participant_id', t.assigned_participant_id, 'title', t.title,
        'description', t.description, 'hint_text', t.hint_text, 'hint_audience', t.hint_audience,
        'status', t.status, 'claimed_at', t.claimed_at, 'decided_at', t.decided_at,
        'published', t.published, 'published_at', t.published_at,
        'trigger_objective_id', t.trigger_objective_id,
        'trigger_objective_title', (select o2.title from saboteur_objectives o2 where o2.id = t.trigger_objective_id),
        'trigger_objective_status', (select o2.status from saboteur_objectives o2 where o2.id = t.trigger_objective_id),
        'hint_released', exists (select 1 from saboteur_hint_releases hr where hr.task_id = t.id)
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

-- ----------------------------------------------------------------------------
-- Spillerens kort: KUN publiserte mål og oppgaver
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
    'status', v_game.status, 'phase', v_game.phase, 'intro', v_game.intro,
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
      from saboteur_objectives o
      where o.assigned_participant_id = v_part.id and o.published
    ) else '[]'::json end,

    'tasks', case when v_part.role = 'LOYAL' then (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'title', t.title, 'description', t.description, 'status', t.status
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t
      where t.assigned_participant_id = v_part.id and t.published
    ) else '[]'::json end,

    'hints', (
      select coalesce(json_agg(json_build_object(
        'task_id', hr.task_id,
        'hint_text', coalesce(nullif(hr.hint_text, ''), t.hint_text),
        'released_at', hr.created_at
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

grant execute on function host_set_objective_published(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_set_task_published(uuid, uuid, boolean) to anon, authenticated;

select record_migration('00022_publish_missions', 'utkast/publisering for mål og oppgaver');
