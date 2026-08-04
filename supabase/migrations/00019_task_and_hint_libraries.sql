-- ============================================================================
-- MIGRASJON 00019 — Oppgavebibliotek og hintkort til de lojale
--
-- Nå får de lojale sin egen motor: 25 ferdige oppgaver, 10 ferdige hintkort,
-- og et hint som deles ut når verten godkjenner en oppgave. Poenget er at de
-- lojale ikke bare sitter og mistenker — de etterforsker.
--
-- HVORDAN HINTET VELGES (den viktige regelen):
--   Har oppgaven en egen hinttekst  ->  den brukes, som før.
--   Er hintfeltet TOMT              ->  det trekkes et TILFELDIG hintkort fra
--                                       biblioteket ved godkjenning.
--
-- Trekningen unngår gjentakelser:
--   • «kun denne spilleren»  -> et kort spilleren ikke har fått før
--   • «alle lojale»          -> ETT kort, likt for alle, som ikke alt er brukt
--                               i spillet (ellers ville folk sammenlignet ulike
--                               hint og trodd de betydde noe forskjellig)
--
-- Teksten som faktisk ble delt ut lagres på selve utdelingen
-- (saboteur_hint_releases.hint_text). Det er nødvendig fordi et tilfeldig hint
-- ikke står noe sted på oppgaven — og det gjør utdelingen historisk korrekt
-- selv om biblioteket endres senere.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) BIBLIOTEKENE
-- ----------------------------------------------------------------------------

create table if not exists saboteur_task_library (
  id         uuid primary key default gen_random_uuid(),
  sort_order int  not null,
  title      text not null,
  created_at timestamptz not null default now()
);
create unique index if not exists saboteur_task_library_sort on saboteur_task_library (sort_order);
alter table saboteur_task_library enable row level security;
revoke all on saboteur_task_library from anon, authenticated;

create table if not exists saboteur_hint_library (
  id         uuid primary key default gen_random_uuid(),
  sort_order int  not null,
  body       text not null,
  created_at timestamptz not null default now()
);
create unique index if not exists saboteur_hint_library_sort on saboteur_hint_library (sort_order);
alter table saboteur_hint_library enable row level security;
revoke all on saboteur_hint_library from anon, authenticated;

do $$
begin
  if exists (select 1 from saboteur_task_library) then
    return;
  end if;

  insert into saboteur_task_library (sort_order, title) values
  (1,  'Få hele rommet til å le samtidig, uten å forklare hvorfor.'),
  (2,  'Få noen til å legge en serviett, caps eller genser på hodet — uten å be dem direkte om det.'),
  (3,  'Få noen til å si ordet «mistenkelig».'),
  (4,  'Få tre personer til å nevne noe uvanlig som har skjedd i kveld, uten å spørre hvem sabotørene er.'),
  (5,  'Få to personer til å forklare hva de tror spillets «agenda» er.'),
  (6,  'Få noen til å spørre: «Hvorfor spør du om det?»'),
  (7,  'Få minst tre personer til å rekke opp hånden på samme spørsmål.'),
  (8,  'Få noen til å gjenta en rar setning som allerede er sagt av en annen spiller.'),
  (9,  'Få to personer til å sammenligne hvilke samtaleemner som har vært rarest i kveld.'),
  (10, 'Få en person til å si at noen «prøver litt for hardt».'),
  (11, 'Få gruppen til å velge mellom to dårlige alternativer, for eksempel pizza resten av livet eller taco resten av livet.'),
  (12, 'Få noen til å etterligne en annen spiller på en vennlig måte.'),
  (13, 'Få noen til å spørre hvem som startet en bestemt samtale eller aktivitet.'),
  (14, 'Få én person til å beskrive en annen spiller med tre positive ord.'),
  (15, 'Få noen til å foreslå at gruppen spiller en lek eller gjør en aktivitet.'),
  (16, 'Få to personer til å bli enige om at noe som skjedde var «helt tilfeldig».'),
  (17, 'Få en person til å oppsummere de siste fem minuttene av samtalen.'),
  (18, 'Få noen til å gi en teori om hvem som virker mest målrettet i kveld.'),
  (19, 'Få en deltaker til å spørre en annen om hvorfor de byttet plass, tema eller aktivitet.'),
  (20, 'Få minst tre personer til å velge en «mest sannsynlig til å …»-kategori.'),
  (21, 'Få noen til å fortelle om en merkelig vane de har.'),
  (22, 'Få en person til å foreslå en skål, applaus eller felles markering.'),
  (23, 'Få noen til å legge merke til at én person har gitt mange komplimenter.'),
  (24, 'Få to personer til å snakke om hvem som har tatt flest initiativ i kveld.'),
  (25, 'Få en spiller til å mistenke en konkret handling, uten å nevne navn.');
end $$;

do $$
begin
  if exists (select 1 from saboteur_hint_library) then
    return;
  end if;

  -- Konkrete nok til å være nyttige, vage nok til ikke å avsløre noen.
  insert into saboteur_hint_library (sort_order, body) values
  (1,  'En sabotør har prøvd å få andre til å gjøre noe.'),
  (2,  'Minst én sabotør har startet en samtale om et uvanlig tema.'),
  (3,  'En sabotør har gitt flere komplimenter enn gjennomsnittet.'),
  (4,  'Målet til en sabotør handler om å få flere personer involvert samtidig.'),
  (5,  'Ingen sabotør har et mål som krever fysisk kontakt.'),
  (6,  'Ett sabotørmål handler om samtale, ikke handling.'),
  (7,  'Minst ett sabotørmål kan løses uten å snakke med mer enn én person.'),
  (8,  'En sabotør har sannsynligvis initiert noe som virket spontant.'),
  (9,  'Ett av målene handler om å få en bestemt formulering sagt høyt.'),
  (10, 'To sabotørmål involverer ulike personer, ikke den samme spilleren flere ganger.');
end $$;

create or replace function list_saboteur_task_library()
returns json
language plpgsql security definer set search_path = public
as $$
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  return (
    select coalesce(json_agg(json_build_object(
      'id', l.id, 'title', l.title, 'sort_order', l.sort_order
    ) order by l.sort_order), '[]'::json)
    from saboteur_task_library l
  );
end $$;

-- Kun for verten: hintkortene er spillinnhold de lojale skal oppdage, ikke
-- lese på forhånd. Derfor host_-prefiks og host_token.
create or replace function host_list_saboteur_hint_library(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  perform _saboteur_host(p_host_token);
  return (
    select coalesce(json_agg(json_build_object(
      'id', l.id, 'body', l.body, 'sort_order', l.sort_order
    ) order by l.sort_order), '[]'::json)
    from saboteur_hint_library l
  );
end $$;

-- ----------------------------------------------------------------------------
-- 2) UTDELINGEN HUSKER HVA SOM FAKTISK BLE GITT
-- ----------------------------------------------------------------------------

alter table saboteur_hint_releases add column if not exists hint_text text;
alter table saboteur_hint_releases add column if not exists library_hint_id uuid
  references saboteur_hint_library (id) on delete set null;

-- Gamle utdelinger hadde teksten på oppgaven; kopier den inn så alle rader
-- er like etter denne migrasjonen.
update saboteur_hint_releases hr
   set hint_text = t.hint_text
  from saboteur_tasks t
 where t.id = hr.task_id and hr.hint_text is null;

-- ----------------------------------------------------------------------------
-- 3) SLIPP-LOGIKKEN: egen tekst, ellers tilfeldig hintkort
-- ----------------------------------------------------------------------------

create or replace function _saboteur_release_hint(p_task_id uuid)
returns int
language plpgsql security definer set search_path = public
as $$
declare
  v_task     saboteur_tasks;
  v_ok       boolean;
  v_text     text;
  v_lib_id   uuid;
  v_released int := 0;
begin
  select * into v_task from saboteur_tasks where id = p_task_id;
  if not found or v_task.status <> 'approved' then
    return 0;
  end if;

  -- Utløser-sjekken fra 00017: uten kobling slippes hintet fritt, med kobling
  -- kreves det at sabotørmålet er godkjent.
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

  v_text := nullif(trim(coalesce(v_task.hint_text, '')), '');

  if v_text is null then
    -- Tomt hintfelt = trekk et tilfeldig kort. Unngå gjentakelser: for én
    -- spiller, et kort de ikke har fått før; for alle lojale, et kort som
    -- ikke alt er brukt i spillet (så ingen sammenligner ulike hint og tror
    -- forskjellen betyr noe).
    if v_task.hint_audience = 'all_loyal' then
      select l.id, l.body into v_lib_id, v_text
      from saboteur_hint_library l
      where not exists (
        select 1 from saboteur_hint_releases hr
        join saboteur_tasks t2 on t2.id = hr.task_id
        where t2.saboteur_game_id = v_task.saboteur_game_id
          and hr.library_hint_id = l.id
      )
      order by random() limit 1;
    else
      select l.id, l.body into v_lib_id, v_text
      from saboteur_hint_library l
      where not exists (
        select 1 from saboteur_hint_releases hr
        where hr.released_to_participant_id = v_task.assigned_participant_id
          and hr.library_hint_id = l.id
      )
      order by random() limit 1;
    end if;

    -- Biblioteket tomt for ubrukte kort: gjenbruk heller enn å gi ingenting.
    if v_text is null then
      select l.id, l.body into v_lib_id, v_text
      from saboteur_hint_library l order by random() limit 1;
    end if;
  end if;

  if v_text is null then
    return 0; -- verken egen tekst eller bibliotek: ingenting å dele ut
  end if;

  if v_task.hint_audience = 'all_loyal' then
    insert into saboteur_hint_releases (task_id, released_to_participant_id, hint_text, library_hint_id)
    select v_task.id, sp.id, v_text, v_lib_id
    from saboteur_participants sp
    where sp.saboteur_game_id = v_task.saboteur_game_id and sp.role = 'LOYAL' and sp.active
    on conflict (task_id, released_to_participant_id) do nothing;
  else
    insert into saboteur_hint_releases (task_id, released_to_participant_id, hint_text, library_hint_id)
    values (v_task.id, v_task.assigned_participant_id, v_text, v_lib_id)
    on conflict (task_id, released_to_participant_id) do nothing;
  end if;

  get diagnostics v_released = row_count;
  return v_released;
end $$;

revoke execute on function _saboteur_release_hint(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4) LEGG TIL OPPGAVE FRA BIBLIOTEKET
--    Begge argumentene kan være null: tilfeldig oppgave, tilfeldig Lojal.
--    Hintfeltet står tomt med vilje — da trekkes hintkortet ved godkjenning.
-- ----------------------------------------------------------------------------

create or replace function host_add_task_from_library(
  p_host_token uuid, p_library_id uuid default null, p_participant_id uuid default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   saboteur_games;
  v_lib    saboteur_task_library;
  v_target uuid := p_participant_id;
  v_id     uuid;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;

  if p_library_id is null then
    select * into v_lib from saboteur_task_library l
    where not exists (
      select 1 from saboteur_tasks t
      where t.saboteur_game_id = v_game.id and t.title = l.title
    )
    order by random() limit 1;

    if v_lib.id is null then
      select * into v_lib from saboteur_task_library order by random() limit 1;
    end if;
    if v_lib.id is null then
      raise exception 'Oppgavebiblioteket er tomt';
    end if;
  else
    select * into v_lib from saboteur_task_library where id = p_library_id;
    if not found then
      raise exception 'Ukjent oppgave i biblioteket';
    end if;
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

  insert into saboteur_tasks (saboteur_game_id, assigned_participant_id, title, hint_text)
  values (v_game.id, v_target, v_lib.title, '')
  returning id into v_id;

  perform _saboteur_audit(v_game.id, 'task_from_library',
    jsonb_build_object('task_id', v_id, 'library_id', v_lib.id));
  return json_build_object('ok', true, 'id', v_id, 'title', v_lib.title);
end $$;

-- ----------------------------------------------------------------------------
-- 5) SPILLERENS HINT: bruk teksten som faktisk ble delt ut
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
      from saboteur_objectives o where o.assigned_participant_id = v_part.id
    ) else '[]'::json end,

    'tasks', case when v_part.role = 'LOYAL' then (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'title', t.title, 'description', t.description, 'status', t.status
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t where t.assigned_participant_id = v_part.id
    ) else '[]'::json end,

    -- Teksten kommer nå fra utdelingen (som kan være et tilfeldig hintkort),
    -- med oppgavens egen tekst som reserve for gamle rader.
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

grant execute on function list_saboteur_task_library() to anon, authenticated;
grant execute on function host_list_saboteur_hint_library(uuid) to anon, authenticated;
grant execute on function host_add_task_from_library(uuid, uuid, uuid) to anon, authenticated;
