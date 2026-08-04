-- ============================================================================
-- MIGRASJON 00017 — Hint som utløses av et fullført sabotørmål («direkte hint»)
--
-- Et hint kan nå VALGFRITT knyttes til et bestemt sabotørmål. Da blir hintet
-- et direkte spor: det slippes ikke ut i lufta, men først når den sabotasjen
-- faktisk har skjedd og verten har godkjent den.
--
-- Regelen, som er lett å tenke feil om:
--   trigger_objective_id = null  ->  som før: hintet slippes når verten
--                                    godkjenner OPPGAVEN.
--   trigger_objective_id satt    ->  det kreves BEGGE deler. Rekkefølgen spiller
--                                    ingen rolle:
--                                      • godkjennes oppgaven først, venter hintet
--                                        til målet godkjennes
--                                      • er målet allerede godkjent, slippes
--                                        hintet i det oppgaven godkjennes
--
-- Slippet er fortsatt idempotent (unik indeks på saboteur_hint_releases), så
-- ingen får det samme hintet to ganger uansett hvilken vei det utløses.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

alter table saboteur_tasks add column if not exists trigger_objective_id uuid
  references saboteur_objectives (id) on delete set null;

create index if not exists saboteur_tasks_trigger_idx
  on saboteur_tasks (trigger_objective_id);

-- ----------------------------------------------------------------------------
-- Felles slipp-logikk, så oppgave-godkjenning og mål-godkjenning ikke kan
-- komme i utakt med hverandre.
-- ----------------------------------------------------------------------------

create or replace function _saboteur_release_hint(p_task_id uuid)
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_task     saboteur_tasks;
  v_ok       boolean;
  v_released int := 0;
begin
  select * into v_task from saboteur_tasks where id = p_task_id;
  if not found or v_task.status <> 'approved' then
    return 0;
  end if;

  -- Er utløseren oppfylt? Uten kobling: ja. Med kobling: bare hvis målet
  -- er godkjent.
  if v_task.trigger_objective_id is null then
    v_ok := true;
  else
    select (status = 'approved') into v_ok
    from saboteur_objectives where id = v_task.trigger_objective_id;
    v_ok := coalesce(v_ok, false);
  end if;

  if not v_ok then
    return 0;
  end if;

  if v_task.hint_audience = 'all_loyal' then
    insert into saboteur_hint_releases (task_id, released_to_participant_id)
    select v_task.id, sp.id from saboteur_participants sp
    where sp.saboteur_game_id = v_task.saboteur_game_id and sp.role = 'LOYAL' and sp.active
    on conflict (task_id, released_to_participant_id) do nothing;
  else
    insert into saboteur_hint_releases (task_id, released_to_participant_id)
    values (v_task.id, v_task.assigned_participant_id)
    on conflict (task_id, released_to_participant_id) do nothing;
  end if;

  get diagnostics v_released = row_count;
  return v_released;
end $$;

revoke execute on function _saboteur_release_hint(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- Oppgaver: valgfri kobling til et sabotørmål
-- ----------------------------------------------------------------------------

create or replace function host_upsert_task(
  p_host_token uuid, p_task_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_hint_text text default null, p_hint_audience text default 'assignee',
  p_trigger_objective_id uuid default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_id       uuid;
  v_title    text := trim(coalesce(p_title, ''));
  v_audience text := coalesce(p_hint_audience, 'assignee');
  v_target   uuid := p_participant_id;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;
  if v_audience not in ('assignee', 'all_loyal') then
    raise exception 'Ukjent mottakergruppe for hintet';
  end if;

  -- Utløseren må være et mål i DETTE spillet.
  if p_trigger_objective_id is not null then
    perform 1 from saboteur_objectives
      where id = p_trigger_objective_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent sabotørmål som utløser';
    end if;
  end if;

  if p_task_id is null then
    if v_title = '' then
      raise exception 'Oppgaven trenger en tittel';
    end if;

    if v_target is null then
      v_target := _saboteur_random_participant(v_game.id, 'LOYAL');
      if v_target is null then
        raise exception 'Ingen aktiv Lojal å tildele oppgaven til';
      end if;
    else
      perform 1 from saboteur_participants
        where id = v_target and saboteur_game_id = v_game.id and role = 'LOYAL';
      if not found then
        raise exception 'Oppgaven må tildeles en Lojal i dette spillet';
      end if;
    end if;

    insert into saboteur_tasks (saboteur_game_id, assigned_participant_id, title, description,
                                hint_text, hint_audience, trigger_objective_id)
    values (v_game.id, v_target, v_title, coalesce(p_description, ''), coalesce(p_hint_text, ''),
            v_audience, p_trigger_objective_id)
    returning id into v_id;
  else
    update saboteur_tasks set
      title                = coalesce(nullif(trim(p_title), ''), title),
      description          = coalesce(p_description, description),
      hint_text            = coalesce(p_hint_text, hint_text),
      hint_audience        = coalesce(p_hint_audience, hint_audience),
      -- Null her betyr «ikke endre». Bruk den dedikerte funksjonen under for
      -- å fjerne en kobling.
      trigger_objective_id = coalesce(p_trigger_objective_id, trigger_objective_id)
    where id = p_task_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent oppgave';
    end if;
    v_id := p_task_id;
  end if;

  perform _saboteur_audit(v_game.id, 'task_upsert',
    jsonb_build_object('task_id', v_id, 'trigger_objective_id', p_trigger_objective_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

-- Fjern koblingen igjen (gjør hintet til et vanlig hint).
create or replace function host_clear_task_trigger(p_host_token uuid, p_task_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  update saboteur_tasks set trigger_objective_id = null
  where id = p_task_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent oppgave';
  end if;

  -- Uten utløser kan et allerede godkjent hint slippes med én gang.
  perform _saboteur_release_hint(p_task_id);

  perform _saboteur_audit(v_game.id, 'task_trigger_cleared', jsonb_build_object('task_id', p_task_id));
  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- Godkjenning: begge veier kan utløse slippet
-- ----------------------------------------------------------------------------

create or replace function host_decide_task_claim(p_host_token uuid, p_task_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_task     saboteur_tasks;
  v_released int := 0;
  v_waiting  boolean := false;
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
    v_released := _saboteur_release_hint(v_task.id);
    -- Ingenting sluppet + kobling satt = hintet venter på at målet godkjennes.
    v_waiting := (v_released = 0 and v_task.trigger_objective_id is not null);
  else
    update saboteur_tasks set status = 'rejected', decided_at = now() where id = v_task.id;
  end if;

  perform _saboteur_audit(v_game.id, 'task_decided',
    jsonb_build_object('task_id', v_task.id, 'approved', p_approve,
                       'hints_released', v_released, 'hint_waiting', v_waiting));
  return json_build_object('ok', true,
    'status', case when p_approve then 'approved' else 'rejected' end,
    'hint_waiting', v_waiting);
end $$;

create or replace function host_decide_objective_claim(p_host_token uuid, p_objective_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_obj      saboteur_objectives;
  v_rowcount int := 0;
  v_task     record;
  v_released int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_obj from saboteur_objectives where id = p_objective_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent mål';
  end if;

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

    -- Slipp hint som har ventet på nettopp dette målet.
    for v_task in
      select id from saboteur_tasks
      where saboteur_game_id = v_game.id
        and trigger_objective_id = v_obj.id
        and status = 'approved'
    loop
      v_released := v_released + _saboteur_release_hint(v_task.id);
    end loop;
  else
    update saboteur_objectives set status = 'rejected', decided_at = now() where id = v_obj.id;
  end if;

  perform _saboteur_audit(v_game.id, 'objective_decided',
    jsonb_build_object('objective_id', v_obj.id, 'approved', p_approve,
                       'points_awarded', v_rowcount > 0, 'hints_released', v_released));
  return json_build_object('ok', true,
    'status', case when p_approve then 'approved' else 'rejected' end,
    'points_awarded', v_rowcount > 0,
    'hints_released', v_released);
end $$;

-- ----------------------------------------------------------------------------
-- Vertsvisningen: vis koblingen, så verten ser hvilke hint som venter
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
        'status', t.status, 'claimed_at', t.claimed_at, 'decided_at', t.decided_at,
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

grant execute on function host_upsert_task(uuid, uuid, uuid, text, text, text, text, uuid) to anon, authenticated;
grant execute on function host_clear_task_trigger(uuid, uuid) to anon, authenticated;

-- Den gamle 7-argumentsversjonen ville ellers ligge igjen og gjøre kallet
-- tvetydig for PostgREST.
drop function if exists host_upsert_task(uuid, uuid, uuid, text, text, text, text);
