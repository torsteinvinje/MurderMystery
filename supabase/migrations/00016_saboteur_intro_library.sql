-- ============================================================================
-- MIGRASJON 00016 — Skjult agenda: introtekst, måbibliotek og tilfeldig tildeling
--
-- Tre ting:
--
-- 1) INTRODUKSJON. Spillet trenger en ramme før det starter: ikke vis skjermen,
--    ikke del meldingene dine, stol på ingen. Teksten ligger på spillet (ikke
--    hardkodet i klienten), så verten kan endre den fra nettsiden.
--
-- 2) MÅLBIBLIOTEK. 30 ferdige mål med poeng, så verten slipper å finne på alt
--    selv. Biblioteket er felles og leses av alle spill; å legge til et mål
--    KOPIERER teksten inn i spillet (samme mønster som mysterier -> fester),
--    slik at senere endringer i biblioteket ikke påvirker et spill som er i gang.
--
-- 3) TILFELDIG TILDELING. Verten kan la databasen velge mottaker: send inn
--    p_participant_id = null, så trekkes en tilfeldig aktiv Sabotør (for mål)
--    eller Lojal (for oppgaver). Trekningen skjer server-side — klienten kan
--    ikke påvirke hvem som blir valgt.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) INTRODUKSJONSTEKST
-- ----------------------------------------------------------------------------

alter table saboteur_games add column if not exists intro text not null default
'Noen blant dere har en skjult agenda. Resten er lojale — men ingen vet hvem som er hvem.

Spillereglene er enkle:

• Ikke vis skjermen din til noen, og ikke les over skulderen på andre.
• Ikke del meldingene du får. De er dine alene.
• Stol på ingen. Folk kommer til å lyve, og noen kommer til å gjøre det godt.
• Forvent rar oppførsel. At noen styrer en samtale, starter en lek eller får deg til å si noe bestemt, kan være helt tilfeldig — eller ikke.
• Vær våken. Legg merke til hvem som gjentar seg, hvem som styrer, og hvem som passer litt for godt på.

Alt kan være tilfeldig. Ingenting er tilfeldig. Lykke til.';

create or replace function host_set_saboteur_intro(p_host_token uuid, p_intro text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_intro text := coalesce(p_intro, '');
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if length(v_intro) > 4000 then
    raise exception 'Introduksjonen er for lang (maks 4000 tegn)';
  end if;

  update saboteur_games set intro = v_intro, updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'intro_updated', '{}'::jsonb);
  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- 2) MÅLBIBLIOTEK
-- ----------------------------------------------------------------------------

create table if not exists saboteur_objective_library (
  id         uuid primary key default gen_random_uuid(),
  sort_order int  not null,
  title      text not null,
  points     int  not null check (points >= 0),
  created_at timestamptz not null default now()
);

create unique index if not exists saboteur_objective_library_sort
  on saboteur_objective_library (sort_order);

alter table saboteur_objective_library enable row level security;
revoke all on saboteur_objective_library from anon, authenticated;

-- Seedes bare hvis biblioteket er tomt, så egne endringer aldri overskrives
-- ved en ny kjøring av migrasjonen.
do $$
begin
  if exists (select 1 from saboteur_objective_library) then
    return;
  end if;

  insert into saboteur_objective_library (sort_order, title, points) values
  (1,  'Få i gang to små leker eller konkurranser i løpet av kvelden.', 3),
  (2,  'Gi fem ekte komplimenter til fem ulike personer.', 2),
  (3,  'Få noen til å åpne en drikke, snackspose eller lignende for deg.', 1),
  (4,  'Få minst tre personer til å stemme over et helt uviktig spørsmål.', 1),
  (5,  'Få noen til å fortelle om sin verste eller beste jobb.', 2),
  (6,  'Start en samtale om et merkverdig historisk tema, som andre verdenskrig, vikinger eller romkappløpet.', 2),
  (7,  'Få to personer til å være uenige om hvilken film, serie eller artist som er best.', 2),
  (8,  'Bruk uttrykket «det er faktisk ganske strategisk» tre ganger uten at noen reagerer.', 2),
  (9,  'Få noen til å demonstrere en dans, et håndtrykk eller en rar ferdighet.', 2),
  (10, 'Få gruppen til å skåle for noe absurd, som «effektiv kollektivtransport» eller «god oppvasklogistikk».', 1),
  (11, 'Få noen til å bytte plass frivillig.', 1),
  (12, 'Få tre personer til å fortelle hva de var opptatt av som barn.', 2),
  (13, 'Få én person til å anbefale en podkast, bok eller dokumentar til hele gruppen.', 1),
  (14, 'Få noen til å velge neste sang.', 1),
  (15, 'Få to personer til å oppdage at de har noe uventet til felles.', 2),
  (16, 'Få minst tre personer til å svare på spørsmålet: «Hva ville du brukt en million på, hvis du måtte bruke alt i morgen?»', 2),
  (17, 'Få noen til å forklare reglene i en sport eller et spill de liker.', 1),
  (18, 'Få gruppen til å applaudere spontant.', 3),
  (19, 'Få noen til å si «det høres mistenkelig ut».', 2),
  (20, 'Få en person til å fortelle en historie fra skole, studietid eller jobb.', 1),
  (21, 'Still tre forskjellige personer samme litt rare spørsmål, for eksempel «hvilken lyd irriterer deg mest?»', 2),
  (22, 'Få noen til å ta et gruppebilde, med alles samtykke.', 2),
  (23, 'Få en person til å lære bort et nytt ord, uttrykk eller dialektord.', 1),
  (24, 'Få to personer til å sammenligne hvem som har reist lengst hjemmefra.', 1),
  (25, 'Introduser en hypotetisk debatt: «Ville du heller hatt én ekstra fridag eller kortere arbeidsdager?»', 1),
  (26, 'Få noen til å etterligne en kjent person eller fiktiv karakter.', 2),
  (27, 'Få minst fire personer til å løfte hånden samtidig.', 2),
  (28, 'Få noen til å foreslå en aktivitet for resten av kvelden.', 2),
  (29, 'Få en deltaker til å forklare hvorfor de tror de er gode i noe.', 1),
  (30, 'Få en samtale til å handle om et veldig spesifikt tema, som heiser, rundkjøringer eller parkeringsregler.', 2);
end $$;

create or replace function list_saboteur_objective_library()
returns json
language plpgsql security definer set search_path = public
as $$
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  return (
    select coalesce(json_agg(json_build_object(
      'id', l.id, 'title', l.title, 'points', l.points, 'sort_order', l.sort_order
    ) order by l.sort_order), '[]'::json)
    from saboteur_objective_library l
  );
end $$;

-- ----------------------------------------------------------------------------
-- 3) TILFELDIG TILDELING
--
-- Intern hjelper: trekk en tilfeldig aktiv deltaker med gitt rolle. Trekningen
-- skjer i databasen, så klienten kan ikke styre utfallet.
-- ----------------------------------------------------------------------------

create or replace function _saboteur_random_participant(p_game_id uuid, p_role text)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  select id into v_id from saboteur_participants
  where saboteur_game_id = p_game_id and role = p_role and active
  order by random() limit 1;
  return v_id;
end $$;

revoke execute on function _saboteur_random_participant(uuid, text) from public, anon, authenticated;

-- Mål: p_participant_id = null ved OPPRETTELSE betyr «trekk en tilfeldig Sabotør».
create or replace function host_upsert_objective(
  p_host_token uuid, p_objective_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_points int default 0, p_expires_at timestamptz default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   saboteur_games;
  v_id     uuid;
  v_title  text := trim(coalesce(p_title, ''));
  v_target uuid := p_participant_id;
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

    if v_target is null then
      v_target := _saboteur_random_participant(v_game.id, 'SABOTEUR');
      if v_target is null then
        raise exception 'Ingen aktiv Sabotør å tildele målet til';
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

-- Oppgaver: samme, men trekker blant de Lojale.
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

    insert into saboteur_tasks (saboteur_game_id, assigned_participant_id, title, description, hint_text, hint_audience)
    values (v_game.id, v_target, v_title, coalesce(p_description, ''), coalesce(p_hint_text, ''), v_audience)
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

-- Legg til et mål fra biblioteket. Begge argumentene kan være null:
--   p_library_id     = null -> trekk et tilfeldig mål som ikke alt er i bruk
--   p_participant_id = null -> trekk en tilfeldig aktiv Sabotør
-- Teksten KOPIERES inn i spillet, så senere endringer i biblioteket påvirker
-- ikke et spill som allerede er i gang.
create or replace function host_add_objective_from_library(
  p_host_token uuid, p_library_id uuid default null, p_participant_id uuid default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   saboteur_games;
  v_lib    saboteur_objective_library;
  v_target uuid := p_participant_id;
  v_id     uuid;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
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

  if v_target is null then
    v_target := _saboteur_random_participant(v_game.id, 'SABOTEUR');
    if v_target is null then
      raise exception 'Ingen aktiv Sabotør å tildele målet til';
    end if;
  else
    perform 1 from saboteur_participants
      where id = v_target and saboteur_game_id = v_game.id and role = 'SABOTEUR';
    if not found then
      raise exception 'Målet må tildeles en Sabotør i dette spillet';
    end if;
  end if;

  insert into saboteur_objectives (saboteur_game_id, assigned_participant_id, title, points)
  values (v_game.id, v_target, v_lib.title, v_lib.points)
  returning id into v_id;

  perform _saboteur_audit(v_game.id, 'objective_from_library',
    jsonb_build_object('objective_id', v_id, 'library_id', v_lib.id));
  return json_build_object('ok', true, 'id', v_id, 'title', v_lib.title, 'points', v_lib.points);
end $$;

-- ----------------------------------------------------------------------------
-- 4) INTRO UT TIL VERT OG SPILLERE
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

grant execute on function host_set_saboteur_intro(uuid, text) to anon, authenticated;
grant execute on function list_saboteur_objective_library() to anon, authenticated;
grant execute on function host_add_objective_from_library(uuid, uuid, uuid) to anon, authenticated;
