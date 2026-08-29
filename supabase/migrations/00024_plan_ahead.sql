-- ============================================================================
-- 00024 — PLANLEGG FØR GJESTENE KOMMER, OG ÅPNE ET AVSLUTTET SPILL IGJEN
--
-- Tre ting verten har manglet:
--
-- 1) Å forberede kvelden i ro og mak. Til nå måtte rollene være delt ut før
--    et eneste sabotørmål kunne skrives — altså midt i selskapet, med folk
--    rundt seg. Nå kan verten legge opp inntil tre BUNKER med mål («Sabotør
--    1», «Sabotør 2», «Sabotør 3») lenge før noen har tastet koden. Bunkene
--    deles ut automatisk når spillet starter: bunke 1 til den første
--    sabotøren, bunke 2 til den andre, og så videre.
--
-- 2) Å endre planen. En bunke kan redigeres, flyttes og slettes helt fram til
--    spillet starter — og går spillet tilbake til utkast, trekkes udelte mål
--    tilbake til bunken sin, slik at neste utdeling blir riktig.
--
-- 3) Å angre. Et avsluttet spill kan åpnes igjen, for å teste eller for å
--    rette opp noe som gikk galt. «Unnsluppet»-bonusene fjernes da, siden de
--    regnes ut på nytt neste gang spillet avsluttes.
--
-- Hemmelighold: et udelt mål har ingen eier, og hver eneste spillerspørring
-- filtrerer på «assigned_participant_id = min id». Planlagte mål kan derfor
-- ikke nå en spiller — de finnes rett og slett ikke for noen ennå.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) SKJEMA: et mål kan nå ligge i en bunke i stedet for hos en person
-- ----------------------------------------------------------------------------

alter table saboteur_objectives alter column assigned_participant_id drop not null;

-- Bunkenummeret. Følger samme 1–3-grense som antall sabotører.
alter table saboteur_objectives add column if not exists planned_slot smallint;

do $$ begin
  alter table saboteur_objectives add constraint saboteur_objectives_slot_check
    check (planned_slot is null or planned_slot between 1 and 3);
exception when duplicate_object then null; end $$;

-- Et mål må høre til noen, eller ligge i en bunke. Aldri ingen av delene —
-- da ville det vært usynlig for både vert og spiller.
do $$ begin
  alter table saboteur_objectives add constraint saboteur_objectives_target_check
    check (assigned_participant_id is not null or planned_slot is not null);
exception when duplicate_object then null; end $$;

create index if not exists saboteur_objectives_planned_idx
  on saboteur_objectives (saboteur_game_id, planned_slot)
  where assigned_participant_id is null;

-- ----------------------------------------------------------------------------
-- 2) UTDELING OG TILBAKETREKKING
-- ----------------------------------------------------------------------------

-- Del bunkene ut til de faktiske sabotørene. Rekkefølgen er den de ble med i,
-- så utdelingen er forutsigbar: bunke 1 til den første sabotøren i lista.
-- Idempotent — et mål som alt har fått eier, røres ikke.
create or replace function _saboteur_deal_planned(p_saboteur_game_id uuid)
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_dealt int := 0;
  v_rows  int;
  v_sab   record;
begin
  for v_sab in
    select id, row_number() over (order by joined_at, id) as slot
    from saboteur_participants
    where saboteur_game_id = p_saboteur_game_id and role = 'SABOTEUR' and active
  loop
    exit when v_sab.slot > 3;   -- flere bunker enn sabotører finnes ikke

    update saboteur_objectives
      set assigned_participant_id = v_sab.id
    where saboteur_game_id = p_saboteur_game_id
      and assigned_participant_id is null
      and planned_slot = v_sab.slot;

    get diagnostics v_rows = row_count;
    v_dealt := v_dealt + v_rows;
  end loop;

  if v_dealt > 0 then
    perform _saboteur_audit(p_saboteur_game_id, 'planned_objectives_dealt',
      jsonb_build_object('dealt', v_dealt));
  end if;
  return v_dealt;
end $$;

-- Motsatt vei: går spillet tilbake til utkast, skal mål som kom fra en bunke
-- tilbake dit. Ellers ville en ny rollefordeling latt et sabotørmål bli
-- liggende hos noen som nettopp ble Lojal — verst tenkelige lekkasje.
-- Mål som alt er meldt inn eller avgjort er historie, og blir stående.
create or replace function _saboteur_undeal_planned(p_saboteur_game_id uuid)
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_rows int;
begin
  update saboteur_objectives
    set assigned_participant_id = null
  where saboteur_game_id = p_saboteur_game_id
    and planned_slot is not null
    and assigned_participant_id is not null
    and status = 'assigned';

  get diagnostics v_rows = row_count;
  if v_rows > 0 then
    perform _saboteur_audit(p_saboteur_game_id, 'planned_objectives_recalled',
      jsonb_build_object('recalled', v_rows));
  end if;
  return v_rows;
end $$;

-- ----------------------------------------------------------------------------
-- 3) STATUSOVERGANGER: utdeling ved start, og «åpne igjen» fra avsluttet
-- ----------------------------------------------------------------------------

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
    ('ended', 'archived'),
    -- Nytt: verten kan angre en avslutning.
    ('ended', 'active')
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

  -- Rekkefølgen er med vilje: statusen settes FØR utdelingen, så et planlagt
  -- mål aldri er synlig i et spill som fortsatt står i utkast.
  if v_game.status = 'draft' and p_new_status = 'active' then
    perform _saboteur_deal_planned(p_saboteur_game_id);
  end if;

  -- Tilbake til utkast: trekk de udelte målene inn igjen, så neste utdeling
  -- følger den nye rollefordelingen.
  if v_game.status = 'active' and p_new_status = 'draft' then
    perform _saboteur_undeal_planned(p_saboteur_game_id);
  end if;

  -- Åpner verten et avsluttet spill igjen, må «unnsluppet»-bonusene bort.
  -- De er ikke historie på samme måte som et godkjent mål — de er en utregning
  -- gjort ved sluttstreken, og sluttstreken flyttes nå. Neste avslutning
  -- regner dem ut på nytt, med stemmetallene som da gjelder.
  if v_game.status = 'ended' and p_new_status = 'active' then
    delete from saboteur_points_ledger
    where source_type = 'undetected'
      and participant_id in (
        select id from saboteur_participants where saboteur_game_id = p_saboteur_game_id
      );
  end if;

  perform _saboteur_audit(
    p_saboteur_game_id,
    case
      when v_game.status = 'active' and p_new_status = 'draft' then 'reopen_roles'
      when v_game.status = 'ended'  and p_new_status = 'active' then 'reopen_game'
      else 'state_change'
    end,
    jsonb_build_object('from', v_game.status, 'to', p_new_status)
  );
end $$;

-- Egen inngang for «åpne igjen», så knappen i vertskontrollen kan si tydelig
-- hva den gjør i stedet for å gjemme seg bak en generisk statusendring.
create or replace function host_reopen_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status <> 'ended' then
    raise exception 'Bare et avsluttet spill kan åpnes igjen';
  end if;

  perform _saboteur_apply_transition(v_game.id, 'active');
  return json_build_object('ok', true, 'status', 'active');
end $$;

-- ----------------------------------------------------------------------------
-- 4) Å SKRIVE MÅL RETT I EN BUNKE
-- ----------------------------------------------------------------------------

create or replace function host_upsert_objective(
  p_host_token uuid, p_objective_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_points int default 0, p_expires_at timestamptz default null,
  p_planned_slot smallint default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   saboteur_games;
  v_id     uuid;
  v_title  text := trim(coalesce(p_title, ''));
  v_target uuid := p_participant_id;
  v_slot   smallint := p_planned_slot;
  v_old    saboteur_objectives;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;
  if v_slot is not null and v_slot not between 1 and 3 then
    raise exception 'Bunken må være 1, 2 eller 3';
  end if;
  -- En bunke er en forberedelse. Etter at spillet har startet finnes det
  -- ekte sabotører å tildele til, og da skal målet dit direkte.
  if v_slot is not null and v_game.status <> 'draft' then
    raise exception 'Bunker kan bare settes opp mens spillet er i utkast';
  end if;

  if p_objective_id is null then
    if v_title = '' then
      raise exception 'Målet trenger en tittel';
    end if;

    if v_slot is not null then
      -- Planlagt mål: ingen eier ennå. Utdelingen skjer når spillet starter.
      insert into saboteur_objectives (saboteur_game_id, assigned_participant_id, planned_slot,
                                       title, description, points, expires_at)
      values (v_game.id, null, v_slot, v_title, coalesce(p_description, ''),
              coalesce(p_points, 0), p_expires_at)
      returning id into v_id;
    else
      if v_target is null then
        v_target := _saboteur_random_participant(v_game.id, 'SABOTEUR');
        if v_target is null then
          raise exception 'Ingen aktiv Sabotør å tildele målet til. Legg det i en bunke i stedet, så deles det ut når spillet starter';
        end if;
      else
        perform 1 from saboteur_participants
          where id = v_target and saboteur_game_id = v_game.id and role = 'SABOTEUR';
        if not found then
          raise exception 'Målet må tildeles en Sabotør i dette spillet';
        end if;
      end if;

      insert into saboteur_objectives (saboteur_game_id, assigned_participant_id, title, description, points, expires_at)
      values (v_game.id, v_target, v_title, coalesce(p_description, ''), coalesce(p_points, 0), p_expires_at)
      returning id into v_id;
    end if;
  else
    select * into v_old from saboteur_objectives
    where id = p_objective_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent mål';
    end if;

    -- Å flytte et mål mellom bunker gir bare mening så lenge det ikke er delt
    -- ut. Er det først hos en sabotør, er bunken bare historikk.
    if v_slot is not null and v_old.assigned_participant_id is not null then
      raise exception 'Målet er alt delt ut til en Sabotør og kan ikke flyttes til en annen bunke';
    end if;

    update saboteur_objectives set
      title        = coalesce(nullif(trim(p_title), ''), title),
      description  = coalesce(p_description, description),
      points       = coalesce(p_points, points),
      expires_at   = coalesce(p_expires_at, expires_at),
      planned_slot = coalesce(v_slot, planned_slot)
    where id = p_objective_id and saboteur_game_id = v_game.id;
    v_id := p_objective_id;
  end if;

  perform _saboteur_audit(v_game.id, 'objective_upsert',
    jsonb_build_object('objective_id', v_id, 'planned_slot', v_slot));
  return json_build_object('ok', true, 'id', v_id);
end $$;

-- Samme mulighet fra det ferdige biblioteket.
create or replace function host_add_objective_from_library(
  p_host_token uuid, p_library_id uuid default null, p_participant_id uuid default null,
  p_planned_slot smallint default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   saboteur_games;
  v_lib    saboteur_objective_library;
  v_target uuid := p_participant_id;
  v_slot   smallint := p_planned_slot;
  v_id     uuid;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;
  if v_slot is not null and v_slot not between 1 and 3 then
    raise exception 'Bunken må være 1, 2 eller 3';
  end if;
  if v_slot is not null and v_game.status <> 'draft' then
    raise exception 'Bunker kan bare settes opp mens spillet er i utkast';
  end if;

  if p_library_id is null then
    -- Foretrekk mål som ikke er brukt i dette spillet ennå.
    select * into v_lib from saboteur_objective_library l
    where not exists (
      select 1 from saboteur_objectives o
      where o.saboteur_game_id = v_game.id and o.title = l.title
    )
    order by random() limit 1;

    if v_lib.id is null then
      select * into v_lib from saboteur_objective_library order by random() limit 1;
    end if;
    if v_lib.id is null then
      raise exception 'Målbiblioteket er tomt';
    end if;
  else
    select * into v_lib from saboteur_objective_library where id = p_library_id;
    if not found then
      raise exception 'Ukjent mål i biblioteket';
    end if;
  end if;

  if v_slot is null then
    if v_target is null then
      v_target := _saboteur_random_participant(v_game.id, 'SABOTEUR');
      if v_target is null then
        raise exception 'Ingen aktiv Sabotør å tildele målet til. Legg det i en bunke i stedet, så deles det ut når spillet starter';
      end if;
    else
      perform 1 from saboteur_participants
        where id = v_target and saboteur_game_id = v_game.id and role = 'SABOTEUR';
      if not found then
        raise exception 'Målet må tildeles en Sabotør i dette spillet';
      end if;
    end if;
  else
    v_target := null;
  end if;

  insert into saboteur_objectives (saboteur_game_id, assigned_participant_id, planned_slot, title, points)
  values (v_game.id, v_target, v_slot, v_lib.title, v_lib.points)
  returning id into v_id;

  perform _saboteur_audit(v_game.id, 'objective_from_library',
    jsonb_build_object('objective_id', v_id, 'library_id', v_lib.id, 'planned_slot', v_slot));
  return json_build_object('ok', true, 'id', v_id, 'title', v_lib.title, 'points', v_lib.points);
end $$;

-- ----------------------------------------------------------------------------
-- 5) AVSTEMNINGSSPERREN MÅ IKKE TELLE UDELTE MÅL
--
-- 00023 nekter å åpne en runde mens et publisert sabotørmål er uavgjort. Et
-- mål som ligger igjen i en bunke ingen sabotør fikk (verten planla for tre,
-- men det ble to) er verken meldt inn eller mulig å avgjøre — uten dette
-- tillegget ville det låst avstemningen for godt.
-- ----------------------------------------------------------------------------

create or replace function host_open_voting_round(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game      saboteur_games;
  v_open      int;
  v_used      int;
  v_unsettled int;
  v_id        uuid;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status not in ('active', 'paused') then
    raise exception 'Spillet må være i gang for å åpne en avstemning';
  end if;

  select count(*) into v_open from saboteur_voting_rounds
  where saboteur_game_id = v_game.id and status = 'open';
  if v_open > 0 then
    raise exception 'Det er allerede en åpen runde';
  end if;

  select count(*) into v_used from saboteur_voting_rounds
  where saboteur_game_id = v_game.id;
  if v_used >= v_game.max_voting_rounds then
    raise exception 'Alle % avstemningsrundene er brukt', v_game.max_voting_rounds;
  end if;

  -- Bevisene skal være inne før noen peker. Udelte mål teller ikke — de har
  -- aldri nådd en spiller.
  select count(*) into v_unsettled
  from saboteur_objectives
  where saboteur_game_id = v_game.id
    and assigned_participant_id is not null
    and published and status in ('assigned', 'claimed');
  if v_unsettled > 0 then
    raise exception
      '% sabotørmål er ikke ferdig. Godkjenn eller avslå dem først (eller trekk dem tilbake) før avstemningen åpnes',
      v_unsettled;
  end if;

  insert into saboteur_voting_rounds (saboteur_game_id, status)
  values (v_game.id, 'open')
  returning id into v_id;

  update saboteur_games set status = 'voting', updated_at = now() where id = v_game.id;

  perform _saboteur_audit(v_game.id, 'voting_opened',
    jsonb_build_object('round_id', v_id, 'round_number', v_used + 1));
  return json_build_object('ok', true, 'round_id', v_id, 'round_number', v_used + 1);
end $$;

-- ----------------------------------------------------------------------------
-- 6) VERTSBILDET: bunkene, og en ærlig oversikt over hvem som gjør noe
--
-- «unsettled_objectives» får samme filter som sperren over, og verten får to
-- nye ting: hvilken bunke hvert planlagt mål ligger i, og en oppsummering per
-- deltaker — hvor mange oppdrag de har, hvor mange de har fullført, og (det
-- verten faktisk lurer på midt i selskapet) hvem som ikke har fått noe ennå.
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
    'max_voting_rounds', v_game.max_voting_rounds,
    'rounds_used', (select count(*) from saboteur_voting_rounds where saboteur_game_id = v_game.id),
    'unsettled_objectives', (
      select count(*) from saboteur_objectives
      where saboteur_game_id = v_game.id and assigned_participant_id is not null
        and published and status in ('assigned', 'claimed')
    ),
    -- Hvor mange mål som fortsatt venter i en bunke, og hvor mange bunker som
    -- er i bruk. Vertskontrollen bruker tallene til å advare når det er
    -- planlagt for flere sabotører enn det faktisk blir.
    'planned_objectives', (
      select count(*) from saboteur_objectives
      where saboteur_game_id = v_game.id and assigned_participant_id is null
    ),
    'planned_slots_used', (
      select coalesce(max(planned_slot), 0) from saboteur_objectives
      where saboteur_game_id = v_game.id and assigned_participant_id is null
    ),
    'created_at', v_game.created_at,

    'participants', (
      select coalesce(json_agg(json_build_object(
        'id', sp.id, 'display_name', sp.display_name, 'role', sp.role, 'active', sp.active,
        'pin', sp.pin,
        'points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = sp.id),
        'points_breakdown', (
          select coalesce(json_object_agg(x.source_type, x.total), '{}'::json)
          from (
            select pl.source_type, sum(pl.points) as total
            from saboteur_points_ledger pl where pl.participant_id = sp.id
            group by pl.source_type
          ) x
        ),
        -- Oppdragsteller per deltaker. Slår sammen mål og oppgaver, så verten
        -- slipper å telle kort manuelt for å se hvem som henger etter.
        'assigned_count', (
          (select count(*) from saboteur_tasks t
            where t.assigned_participant_id = sp.id and t.published)
          + (select count(*) from saboteur_objectives o
            where o.assigned_participant_id = sp.id and o.published)
        ),
        'draft_count', (
          (select count(*) from saboteur_tasks t
            where t.assigned_participant_id = sp.id and not t.published)
          + (select count(*) from saboteur_objectives o
            where o.assigned_participant_id = sp.id and not o.published)
        ),
        'claimed_count', (
          (select count(*) from saboteur_tasks t
            where t.assigned_participant_id = sp.id and t.published and t.status = 'claimed')
          + (select count(*) from saboteur_objectives o
            where o.assigned_participant_id = sp.id and o.published and o.status = 'claimed')
        ),
        'approved_count', (
          (select count(*) from saboteur_tasks t
            where t.assigned_participant_id = sp.id and t.status = 'approved')
          + (select count(*) from saboteur_objectives o
            where o.assigned_participant_id = sp.id and o.status = 'approved')
        )
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
        'planned_slot', o.planned_slot,
        'status', o.status, 'claimed_at', o.claimed_at, 'decided_at', o.decided_at,
        'published', o.published, 'published_at', o.published_at
      ) order by o.planned_slot nulls first, o.created_at), '[]'::json)
      from saboteur_objectives o where o.saboteur_game_id = v_game.id
    ),

    'tasks', (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'participant_id', t.assigned_participant_id, 'title', t.title,
        'description', t.description, 'hint_text', t.hint_text, 'hint_audience', t.hint_audience,
        'points', t.points,
        'status', t.status, 'claimed_at', t.claimed_at, 'decided_at', t.decided_at,
        'published', t.published, 'published_at', t.published_at,
        'trigger_objective_id', t.trigger_objective_id,
        'trigger_objective_title', (select o2.title from saboteur_objectives o2 where o2.id = t.trigger_objective_id),
        'trigger_objective_status', (select o2.status from saboteur_objectives o2 where o2.id = t.trigger_objective_id),
        'hint_released', exists (select 1 from saboteur_hint_releases hr where hr.task_id = t.id)
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t where t.saboteur_game_id = v_game.id
    ),

    'round', case when v_round.id is null then null else json_build_object(
      'id', v_round.id, 'status', v_round.status,
      'opened_at', v_round.opened_at, 'closed_at', v_round.closed_at, 'revealed_at', v_round.revealed_at,
      'ballot_count', (select count(*) from saboteur_ballots b where b.voting_round_id = v_round.id),
      'tally', case when v_round.status = 'revealed' then (
        select coalesce(json_agg(json_build_object(
          'display_name', x.display_name, 'votes', x.votes
        ) order by x.votes desc), '[]'::json)
        from (
          select sp.display_name, count(b.id) as votes
          from saboteur_ballots b
          join saboteur_participants sp on sp.id = b.target_participant_id
          where b.voting_round_id = v_round.id
          group by sp.id, sp.display_name
        ) x
      ) else null end,
      'reasons', case when v_round.status = 'revealed' then (
        select coalesce(json_agg(json_build_object(
          'voter', voter.display_name, 'target', target.display_name, 'reason', b.reason
        ) order by voter.display_name), '[]'::json)
        from saboteur_ballots b
        join saboteur_participants voter on voter.id = b.voter_participant_id
        join saboteur_participants target on target.id = b.target_participant_id
        where b.voting_round_id = v_round.id and b.reason is not null
      ) else null end
    ) end
  );
end $$;

-- ----------------------------------------------------------------------------
-- 7) OPPRYDDING OG RETTIGHETER
-- ----------------------------------------------------------------------------

-- De gamle signaturene må bort, ellers blir kallet tvetydig for PostgREST.
drop function if exists host_upsert_objective(uuid, uuid, uuid, text, text, int, timestamptz);
drop function if exists host_add_objective_from_library(uuid, uuid, uuid);

grant execute on function host_reopen_saboteur_game(uuid) to anon, authenticated;
grant execute on function host_upsert_objective(uuid, uuid, uuid, text, text, int, timestamptz, smallint) to anon, authenticated;
grant execute on function host_add_objective_from_library(uuid, uuid, uuid, smallint) to anon, authenticated;

select record_migration('00024_plan_ahead', 'planlagte målbunker, oppdragsoversikt, åpne avsluttet spill igjen');
