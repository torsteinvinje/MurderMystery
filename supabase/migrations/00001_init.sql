-- ============================================================================
-- LJÅMORDET PÅ GRILLFESTEN — komplett databaseskjema
--
-- Kjør hele denne fila i Supabase SQL Editor (den kan trygt kjøres på nytt).
-- Samme innhold ligger som supabase/migrations/00001_init.sql.
--
-- Sikkerhetsmodell (viktig å forstå før du endrer noe):
--   1. RLS er PÅ for alle tabeller, uten policies for direkte lesing/skriving.
--      Klienten kan altså ALDRI lese eller skrive tabeller direkte.
--   2. All tilgang går via SECURITY DEFINER-funksjoner (RPC-ene nederst).
--      De validerer host_token / player_token og returnerer bare trygge felt.
--   3. Morderen (suspects.is_killer) og oppklaringen (games.resolution)
--      forlater aldri databasen til en spiller før verten har satt status
--      'revealed' — eneste vei ut er get_reveal, som sjekker statusen.
--      I tillegg er kolonnene sperret med kolonne-grants (belte og bukseseler).
--   4. game_events er en ufarlig "noe har skjedd"-strøm som Realtime lytter
--      på. Den inneholder aldri spillinnhold — klienten henter alt på nytt
--      via RPC-ene når den får et dytt.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) TABELLER
-- ----------------------------------------------------------------------------

create table if not exists games (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,                -- festkoden gjestene taster inn
  host_token  uuid not null default gen_random_uuid(),  -- hemmelig vertsnøkkel
  status      text not null default 'lobby'
              check (status in ('lobby', 'in_progress', 'revealed', 'finished')),
  phase       text not null default 'velkommen',
  title       text not null,
  intro       text not null,
  resolution  text not null,                       -- BESKYTTET: kun host + get_reveal
  created_at  timestamptz not null default now()
);

create table if not exists suspects (
  id          uuid primary key default gen_random_uuid(),
  game_id     uuid not null references games (id) on delete cascade,
  sort_order  int  not null default 0,
  name        text not null,
  tagline     text not null default '',            -- kort rollebeskrivelse
  public_info text not null default '',            -- det alle på festen vet
  secret      text not null default '',            -- kun spilleren med rollen ser denne
  alibi       text not null default '',
  is_killer   boolean not null default false,      -- BESKYTTET: kun host + get_reveal
  created_at  timestamptz not null default now()
);

create table if not exists players (
  id           uuid primary key default gen_random_uuid(),
  game_id      uuid not null references games (id) on delete cascade,
  player_token uuid not null unique default gen_random_uuid(), -- hemmelig spillernøkkel
  display_name text not null,
  suspect_id   uuid references suspects (id) on delete set null,
  joined_at    timestamptz not null default now()
);

-- En rolle kan bare være delt ut til én spiller om gangen.
create unique index if not exists players_suspect_unique
  on players (suspect_id) where suspect_id is not null;

create table if not exists polaroids (
  id         uuid primary key default gen_random_uuid(),
  game_id    uuid not null references games (id) on delete cascade,
  sort_order int  not null default 0,
  title      text not null default '',
  caption    text not null default '',
  image_url  text,
  revealed   boolean not null default false,       -- spillere ser kun revealed = true
  created_at timestamptz not null default now()
);

create table if not exists suspicions (
  id         uuid primary key default gen_random_uuid(),
  player_id  uuid not null references players (id) on delete cascade,
  suspect_id uuid not null references suspects (id) on delete cascade,
  level      int  not null default 0 check (level between 0 and 3),
  updated_at timestamptz not null default now(),
  unique (player_id, suspect_id)
);

-- Ufarlig hendelsesstrøm for Realtime. Inneholder aldri innhold.
create table if not exists game_events (
  id         bigint generated always as identity primary key,
  game_id    uuid not null references games (id) on delete cascade,
  kind       text not null,
  created_at timestamptz not null default now()
);

create index if not exists game_events_game_idx on game_events (game_id, id);

-- Maler: innholdet et nytt spill kopieres fra (create_game).
create table if not exists story_template (
  id         int primary key check (id = 1),
  title      text not null,
  intro      text not null,
  resolution text not null
);

create table if not exists suspect_templates (
  sort_order  int primary key,
  name        text not null,
  tagline     text not null,
  public_info text not null,
  secret      text not null,
  alibi       text not null,
  is_killer   boolean not null default false
);

create table if not exists polaroid_templates (
  sort_order int primary key,
  title      text not null,
  caption    text not null
);

-- ----------------------------------------------------------------------------
-- 2) RLS OG RETTIGHETER
-- ----------------------------------------------------------------------------

alter table games             enable row level security;
alter table suspects          enable row level security;
alter table players           enable row level security;
alter table polaroids         enable row level security;
alter table suspicions        enable row level security;
alter table game_events       enable row level security;
alter table story_template    enable row level security;
alter table suspect_templates enable row level security;
alter table polaroid_templates enable row level security;

-- Ingen policies = ingen direkte tilgang for klienter. Eneste unntak er
-- game_events, som Realtime trenger å kunne lese (den er ufarlig).
drop policy if exists game_events_read on game_events;
create policy game_events_read on game_events
  for select to anon, authenticated using (true);

-- Fjern alle direkte tabellrettigheter fra klientrollene...
revoke all on all tables in schema public from anon, authenticated;

-- ...og gi tilbake nøyaktig det som er trygt:
grant select on game_events to anon, authenticated;

-- Kolonne-grants som ekstra sperre (belte og bukseseler): selv om noen ved et
-- uhell skulle legge til en RLS-policy senere, kan klientroller aldri SELECT-e
-- is_killer, resolution eller tokens.
grant select (id, code, status, phase, title, intro, created_at)
  on games to anon, authenticated;
grant select (id, game_id, sort_order, name, tagline, public_info, created_at)
  on suspects to anon, authenticated;

-- Realtime lytter på game_events (trygt å kjøre flere ganger).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'game_events'
  ) then
    alter publication supabase_realtime add table game_events;
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- 3) SEED-INNHOLD (malene et nytt spill kopieres fra)
-- ----------------------------------------------------------------------------

delete from story_template;
insert into story_template (id, title, intro, resolution) values (
  1,
  'Ljåmordet på grillfesten',
  'Sommerkvelden på Vollan gård begynte med grillos, rabarbrasaft og gjensynsglede — og endte med et lik. Klokka halv ti fant grillmesteren verten selv, Odd Gunnar Vollan (61), bak redskapsskjulet. Ved siden av ham: gårdens gamle ljå. Grinden til tunet har vært lukket hele kvelden. Ingen har kommet, og ingen har gått. Morderen står fortsatt her — med saftglass i hånda. Lensmannen har tatt saken, og ingen forlater festen før den er løst.',
  'Det var Randi Espeland, banksjefen. I årevis hadde hun dekket egne tap ved å «låne» fra kundenes kontoer — og forfalsket Odd Gunnars signatur på lånepapirene til det nye fjøset. Dagen før festen oppdaget Odd Gunnar det, og ga henne frist til mandag: meld deg selv, ellers ringer jeg Økokrim. Under festen ba han henne møte seg bak redskapsskjulet for å gi henne en siste sjanse. Hun tok med lånepapirene for å brenne dem på grillen — og da han snudde ryggen til, grep hun ljåen fra skjulveggen. Alibiet hennes sprakk med ett eneste gjestebilde: klokka 21.12 var kjøkkenet tomt og kaffetrakteren kald. Smalt støvelavtrykk i størrelse 38. Brente lånepapirer med falsk signatur i grillen. Og i notatboka til Odd Gunnar: «RE: frist mandag». RE. Randi Espeland. Sak avsluttet.'
);

delete from suspect_templates;
insert into suspect_templates (sort_order, name, tagline, public_info, secret, alibi, is_killer) values
(1, 'Solveig Vollan', 'Kona på gården',
 'Gift med Odd Gunnar i 34 år. Sto for potetsalaten og smilte til alle hele kvelden — kanskje litt for bredt.',
 'Du fant skilsmissepapirer i skrivebordet til Odd Gunnar forrige uke. Han skulle forlate deg — og ta gården med seg. Du har ikke fortalt det til noen, og du nekter å la noen få vite at ekteskapet var en fasade.',
 'Jeg sto ved langbordet og skjenket rabarbrasaft fra halv ni til kvart på ti. Spør hvem som helst — glassene var aldri tomme.',
 false),
(2, 'Linn Vollan', 'Datteren som kom hjem',
 'Flyttet til Oslo for åtte år siden. Dukket uventet opp på festen — første gang på gården siden jul.',
 'Du skylder 340 000 kroner etter nettpoker. Du kom hjem for å be far om forskudd på arven. Han sa nei — høylytt — bak låven klokka kvart på ni. Flere kan ha hørt dere.',
 'Jeg satt på trappa og røykte og så på solnedgangen. Alene, dessverre. Men jeg hørte musikken hele tiden.',
 false),
(3, 'Birger Brakstad', 'Naboen med grensetvisten',
 'Grunneier på nabogården. Har kranglet med Odd Gunnar om et jorde i tolv år. Kom likevel i år — med hjemmelaget bringebærsaft som fredsgave.',
 'Grensesaken skulle opp i jordskifteretten neste måned, og advokaten din sa rett ut at du kom til å tape alt. Med Odd Gunnar borte stopper hele saken. Du klarer ikke å slutte å tenke på det.',
 'Jeg var borte ved vedstabelen og hentet mer ved til bålpanna. Det tar tid å finne tørr bjørk, vet du.',
 false),
(4, 'Kjell-Arne Mo', 'Gårdsarbeideren',
 'Har jobbet på Vollan gård i ni år. Kjenner hver krok av gården — og vet hvor alt verktøyet henger.',
 'Odd Gunnar ga deg sparken samme morgen. «Effektivisering», sa han. Du har ikke sagt det til noen — kona di tror fortsatt alt er som før. Du var rasende hele dagen.',
 'Jeg grillet maiskolber på den lille grillen på baksiden. Der er det bare meg, som vanlig. Ingen ser gårdsarbeideren før maten er klar.',
 false),
(5, 'Randi Espeland', 'Banksjefen',
 'Banksjef i bygda i femten år. Ordnet lånet da Vollan bygde nytt fjøs. Alltid pen i tøyet, alltid først til å skåle.',
 'Du har «lånt» av kundenes kontoer for å dekke egne tap — og forfalsket Odd Gunnars signatur på lånepapirer. I går oppdaget han det og ga deg frist til mandag med å melde deg selv. Du MÅ få tak i papirene han sitter på, og ingen kan få vite om fristen.',
 'Jeg var på kjøkkenet, satte på kaffetrakteren og ordnet kransekaka. Kjøkkenvinduet vender jo rett mot tunet — jeg så dere alle sammen.',
 true),
(6, 'Petter «Pjokken» Hauge', 'Grillmesteren',
 'Bygdas selvutnevnte grillkonge. Var sammen med Linn på videregående og har aldri helt kommet over det. Det var han som fant Odd Gunnar.',
 'Du så en skikkelse i mørke klær gå mot redskapsskjulet rundt klokka ni. Du tør ikke si det høyt — for da må du innrømme hvor du selv sto: bak låven, der du øvde deg på å be Linn ut igjen.',
 'Grillen, selvfølgelig! En grillmester forlater aldri grillen. Bortsett fra da jeg hentet mer marinade. To minutter, maks. Kanskje fem.',
 false),
(7, 'Ingrid Sæter', 'Veterinæren',
 'Bygdas veterinær. Var på gården så sent som i forrige uke for å se til en halt hoppe.',
 'Rapporten din fra forrige uke skjuler noe: du fant tegn på vanskjøtsel i fjøset, men Odd Gunnar betalte deg for å «runde av» formuleringene. Kommer det ut, mister du lisensen. Du håper inderlig ingen ber om å få se rapporten.',
 'Jeg var nede ved hestehagen og så til hoppa. Dyr merker uro lenge før mennesker, vet du. Hun var rastløs hele kvelden.',
 false),
(8, 'Tormod Lien', 'Den pensjonerte lensmannen',
 'Bygdas lensmann i tretti år, nå pensjonist. Glemmer aldri et ansikt. Odd Gunnars gamle jaktkamerat.',
 'For tjue år siden henla du en sak mot Odd Gunnar om forsikringssvindel — mot at han holdt munn om fyllekjøringen din. Han har «mint deg på det» hver eneste jul siden. Du kom på festen for å be ham slette gjelda en gang for alle.',
 'Jeg satt i fluktstolen ved bålpanna hele kvelden. Gamle knær, unge øyne. Jeg så alt — trodde jeg.',
 false);

delete from polaroid_templates;
insert into polaroid_templates (sort_order, title, caption) values
(1, 'Ljåen',
 'Gårdens gamle ljå, funnet ved siden av Odd Gunnar. Skaftet er tørket omhyggelig rent — med en serviett fra festen. Morderen tenkte klart nok til å fjerne spor.'),
(2, 'Fotavtrykk bak skjulet',
 'Et smalt støvelavtrykk i den myke jorda bak redskapsskjulet. Størrelse 38, med fin hæl. Dette er ingen arbeidsstøvel.'),
(3, 'Notatboka til Odd Gunnar',
 'Siste side i notatboka, skrevet med hardt pennetrykk: «RE: frist mandag. Ellers ringer jeg Økokrim.»'),
(4, 'Kjøkkenvinduet kl. 21.12',
 'Et gjestebilde tatt mot tunet klokka 21.12. I bakgrunnen ses kjøkkenvinduet tydelig. Kjøkkenet er tomt — og kaffetrakteren står ikke på.'),
(5, 'Grillen',
 'Noen har brent papirer i grillen etter at maten var ferdig. Ett hjørne overlevde flammene: «...esignatur: Odd Gunnar Voll...» — men håndskriften er ikke hans.'),
(6, 'Veska i gangen',
 'En åpen veske i gangen. Opp av lomma stikker det som ser ut som skilsmissepapirer — med Solveig Vollans navn på.');

-- ----------------------------------------------------------------------------
-- 4) INTERNE HJELPEFUNKSJONER (ikke kallbare fra klienten)
-- ----------------------------------------------------------------------------

-- Slår opp spillet til en vert, eller feiler med norsk feilmelding.
create or replace function _host_game(p_host_token uuid)
returns games
language plpgsql security definer set search_path = public
as $$
declare
  v_game games;
begin
  if p_host_token is null then
    raise exception 'Mangler vertsnøkkel';
  end if;
  select * into v_game from games where host_token = p_host_token;
  if not found then
    raise exception 'Ugyldig vertsnøkkel — fant ikke spillet';
  end if;
  return v_game;
end $$;

-- Slår opp spilleren bak en spillernøkkel.
create or replace function _player(p_player_token uuid)
returns players
language plpgsql security definer set search_path = public
as $$
declare
  v_player players;
begin
  if p_player_token is null then
    raise exception 'Mangler spillernøkkel';
  end if;
  select * into v_player from players where player_token = p_player_token;
  if not found then
    raise exception 'Ugyldig spillernøkkel — fant ikke spilleren';
  end if;
  return v_player;
end $$;

-- Legger inn et "noe har skjedd"-dytt som Realtime plukker opp.
create or replace function _poke(p_game_id uuid, p_kind text)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into game_events (game_id, kind) values (p_game_id, p_kind);
end $$;

revoke execute on function _host_game(uuid) from public, anon, authenticated;
revoke execute on function _player(uuid) from public, anon, authenticated;
revoke execute on function _poke(uuid, text) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 5) RPC: SPILLOPPSETT OG INNMELDING
-- ----------------------------------------------------------------------------

-- Oppretter et nytt spill fra malene og returnerer vertsnøkkelen.
create or replace function create_game()
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  games;
  v_code  text;
  v_chars text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- uten lett forvekslbare tegn
begin
  -- Finn en ledig firetegns festkode.
  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from games where code = v_code);
  end loop;

  insert into games (code, title, intro, resolution)
  select v_code, t.title, t.intro, t.resolution
  from story_template t
  where t.id = 1
  returning * into v_game;

  if v_game.id is null then
    raise exception 'Fant ikke historiemalen — er hele skjemafila kjørt?';
  end if;

  insert into suspects (game_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
  select v_game.id, t.sort_order, t.name, t.tagline, t.public_info, t.secret, t.alibi, t.is_killer
  from suspect_templates t;

  insert into polaroids (game_id, sort_order, title, caption)
  select v_game.id, t.sort_order, t.title, t.caption
  from polaroid_templates t;

  perform _poke(v_game.id, 'game');

  return json_build_object(
    'game_id', v_game.id,
    'code', v_game.code,
    'host_token', v_game.host_token
  );
end $$;

-- En gjest melder seg inn med festkode og navn.
create or replace function join_game(p_code text, p_name text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   games;
  v_player players;
  v_name   text := trim(coalesce(p_name, ''));
  v_code   text := upper(trim(coalesce(p_code, '')));
begin
  if v_name = '' then
    raise exception 'Du må skrive inn et navn';
  end if;
  if length(v_name) > 40 then
    raise exception 'Navnet er for langt (maks 40 tegn)';
  end if;

  select * into v_game from games where code = v_code;
  if not found then
    raise exception 'Fant ingen fest med koden «%»', v_code;
  end if;
  if v_game.status in ('revealed', 'finished') then
    raise exception 'Denne festen er avsluttet';
  end if;

  insert into players (game_id, display_name)
  values (v_game.id, v_name)
  returning * into v_player;

  perform _poke(v_game.id, 'players');

  return json_build_object(
    'player_token', v_player.player_token,
    'player_id', v_player.id,
    'game_id', v_game.id,
    'code', v_game.code
  );
end $$;

-- ----------------------------------------------------------------------------
-- 6) RPC: SPILLERFUNKSJONER
-- (returnerer ALDRI is_killer eller resolution — bortsett fra get_reveal
--  etter at verten har avslørt)
-- ----------------------------------------------------------------------------

-- Spillerens eget kort: spillet, spilleren og evt. tildelt rolle (med hemmelighet).
create or replace function get_my_player(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players := _player(p_player_token);
  v_result json;
begin
  select json_build_object(
    'player', json_build_object('id', p.id, 'display_name', p.display_name),
    'game', json_build_object(
      'id', g.id, 'code', g.code, 'status', g.status,
      'phase', g.phase, 'title', g.title, 'intro', g.intro
    ),
    'suspect', case when s.id is null then null else json_build_object(
      'id', s.id, 'name', s.name, 'tagline', s.tagline,
      'public_info', s.public_info, 'secret', s.secret, 'alibi', s.alibi
    ) end
  )
  into v_result
  from players p
  join games g on g.id = p.game_id
  left join suspects s on s.id = p.suspect_id
  where p.id = v_player.id;

  return v_result;
end $$;

-- Alle mistenkte i spillet — kun offentlige felt (til mistankelista).
create or replace function get_public_suspects(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players := _player(p_player_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', s.id, 'name', s.name, 'tagline', s.tagline,
      'public_info', s.public_info, 'sort_order', s.sort_order
    ) order by s.sort_order), '[]'::json)
    from suspects s
    where s.game_id = v_player.game_id
  );
end $$;

-- Kun polaroider verten har avslørt.
create or replace function get_public_polaroids(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players := _player(p_player_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', pol.id, 'title', pol.title, 'caption', pol.caption,
      'image_url', pol.image_url, 'sort_order', pol.sort_order
    ) order by pol.sort_order), '[]'::json)
    from polaroids pol
    where pol.game_id = v_player.game_id
      and pol.revealed
  );
end $$;

-- Sett mistankenivå (0–3) på en mistenkt.
create or replace function set_suspicion(p_player_token uuid, p_suspect_id uuid, p_level int)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players := _player(p_player_token);
begin
  if p_level is null or p_level < 0 or p_level > 3 then
    raise exception 'Mistankenivå må være mellom 0 og 3';
  end if;

  perform 1 from suspects where id = p_suspect_id and game_id = v_player.game_id;
  if not found then
    raise exception 'Ukjent mistenkt';
  end if;

  insert into suspicions (player_id, suspect_id, level)
  values (v_player.id, p_suspect_id, p_level)
  on conflict (player_id, suspect_id)
  do update set level = excluded.level, updated_at = now();

  perform _poke(v_player.game_id, 'suspicions');
  return json_build_object('ok', true);
end $$;

-- Spillerens egne mistanker.
create or replace function get_my_suspicions(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players := _player(p_player_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'suspect_id', su.suspect_id, 'level', su.level
    )), '[]'::json)
    from suspicions su
    where su.player_id = v_player.id
  );
end $$;

-- DEN VIKTIGSTE SPERREN I APPEN: morderen og oppklaringen er kun
-- tilgjengelig etter at verten har satt status til 'revealed'.
create or replace function get_reveal(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players := _player(p_player_token);
  v_game   games;
begin
  select * into v_game from games where id = v_player.game_id;

  if v_game.status <> 'revealed' then
    raise exception 'Avsløringen er ikke klar ennå';
  end if;

  return (
    select json_build_object(
      'killer', json_build_object('id', s.id, 'name', s.name, 'tagline', s.tagline),
      'resolution', v_game.resolution
    )
    from suspects s
    where s.game_id = v_game.id and s.is_killer
    limit 1
  );
end $$;

-- ----------------------------------------------------------------------------
-- 7) RPC: VERTSFUNKSJONER (krever gyldig host_token)
-- ----------------------------------------------------------------------------

-- Hele spillet, inkludert oppklaringen (kun verten ser denne før reveal).
create or replace function host_get_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return json_build_object(
    'id', v_game.id, 'code', v_game.code, 'status', v_game.status,
    'phase', v_game.phase, 'title', v_game.title, 'intro', v_game.intro,
    'resolution', v_game.resolution, 'created_at', v_game.created_at
  );
end $$;

create or replace function host_list_players(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', p.id, 'display_name', p.display_name, 'joined_at', p.joined_at,
      'suspect_id', p.suspect_id, 'suspect_name', s.name
    ) order by p.joined_at), '[]'::json)
    from players p
    left join suspects s on s.id = p.suspect_id
    where p.game_id = v_game.id
  );
end $$;

-- Verten ser alt — inkludert hvem som er morderen.
create or replace function host_get_suspects(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', s.id, 'sort_order', s.sort_order, 'name', s.name,
      'tagline', s.tagline, 'public_info', s.public_info,
      'secret', s.secret, 'alibi', s.alibi, 'is_killer', s.is_killer
    ) order by s.sort_order), '[]'::json)
    from suspects s
    where s.game_id = v_game.id
  );
end $$;

-- Alle polaroider, også de som ikke er avslørt ennå.
create or replace function host_get_polaroids(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', pol.id, 'sort_order', pol.sort_order, 'title', pol.title,
      'caption', pol.caption, 'image_url', pol.image_url, 'revealed', pol.revealed
    ) order by pol.sort_order), '[]'::json)
    from polaroids pol
    where pol.game_id = v_game.id
  );
end $$;

-- Mistankeoversikt: sum av nivåer og antall "hovedmistenkt"-merker per mistenkt.
create or replace function host_get_suspicions(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return (
    select coalesce(json_agg(row_to_json(t)), '[]'::json)
    from (
      select s.id as suspect_id,
             s.name,
             coalesce(sum(su.level), 0)::int as total,
             (count(su.id) filter (where su.level = 3))::int as top_marks
      from suspects s
      left join suspicions su on su.suspect_id = s.id
      where s.game_id = v_game.id
      group by s.id, s.name, s.sort_order
      order by total desc, s.sort_order
    ) t
  );
end $$;

create or replace function host_set_phase(p_host_token uuid, p_phase text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  if p_phase not in ('velkommen', 'roller', 'mingling', 'ledetraader',
                     'forhor', 'avstemning', 'avsloring') then
    raise exception 'Ukjent fase: %', p_phase;
  end if;

  update games set phase = p_phase where id = v_game.id;
  perform _poke(v_game.id, 'phase');
  return json_build_object('ok', true, 'phase', p_phase);
end $$;

create or replace function host_set_status(p_host_token uuid, p_status text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  if p_status not in ('lobby', 'in_progress', 'revealed', 'finished') then
    raise exception 'Ukjent status: %', p_status;
  end if;

  update games set status = p_status where id = v_game.id;
  perform _poke(v_game.id, 'status');
  return json_build_object('ok', true, 'status', p_status);
end $$;

-- Del ut (eller trekk tilbake, med null) en rolle til en spiller.
create or replace function host_assign_suspect(p_host_token uuid, p_player_id uuid, p_suspect_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  perform 1 from players where id = p_player_id and game_id = v_game.id;
  if not found then
    raise exception 'Ukjent spiller';
  end if;

  if p_suspect_id is not null then
    perform 1 from suspects where id = p_suspect_id and game_id = v_game.id;
    if not found then
      raise exception 'Ukjent mistenkt';
    end if;
    perform 1 from players where suspect_id = p_suspect_id and id <> p_player_id;
    if found then
      raise exception 'Den rollen er allerede delt ut';
    end if;
  end if;

  update players set suspect_id = p_suspect_id where id = p_player_id;
  perform _poke(v_game.id, 'players');
  return json_build_object('ok', true);
end $$;

-- Del ut ledige roller tilfeldig til spillere uten rolle.
create or replace function host_auto_assign(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     games := _host_game(p_host_token);
  v_player   record;
  v_suspect  uuid;
  v_assigned int := 0;
begin
  for v_player in
    select id from players
    where game_id = v_game.id and suspect_id is null
    order by random()
  loop
    select s.id into v_suspect
    from suspects s
    where s.game_id = v_game.id
      and not exists (select 1 from players p2 where p2.suspect_id = s.id)
    order by random()
    limit 1;

    exit when v_suspect is null; -- flere spillere enn roller: resten blir etterforskere

    update players set suspect_id = v_suspect where id = v_player.id;
    v_assigned := v_assigned + 1;
  end loop;

  perform _poke(v_game.id, 'players');
  return json_build_object('ok', true, 'assigned', v_assigned);
end $$;

create or replace function host_reveal_polaroid(p_host_token uuid, p_polaroid_id uuid, p_revealed boolean default true)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  update polaroids set revealed = p_revealed
  where id = p_polaroid_id and game_id = v_game.id;
  if not found then
    raise exception 'Ukjent polaroid';
  end if;

  perform _poke(v_game.id, 'polaroids');
  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- 8) RPC: VERTENS INNHOLDSREDIGERING (writeback)
-- ----------------------------------------------------------------------------

-- Oppdater tekstfeltene på en mistenkt. is_killer kan IKKE endres herfra.
create or replace function host_update_suspect(
  p_host_token uuid, p_suspect_id uuid,
  p_name text default null, p_tagline text default null,
  p_public_info text default null, p_secret text default null,
  p_alibi text default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  update suspects set
    name        = coalesce(p_name, name),
    tagline     = coalesce(p_tagline, tagline),
    public_info = coalesce(p_public_info, public_info),
    secret      = coalesce(p_secret, secret),
    alibi       = coalesce(p_alibi, alibi)
  where id = p_suspect_id and game_id = v_game.id;
  if not found then
    raise exception 'Ukjent mistenkt';
  end if;

  perform _poke(v_game.id, 'suspects');
  return json_build_object('ok', true);
end $$;

-- Opprett (p_polaroid_id = null) eller oppdater et polaroid.
create or replace function host_upsert_polaroid(
  p_host_token uuid, p_polaroid_id uuid default null,
  p_title text default null, p_caption text default null,
  p_image_url text default null, p_sort_order int default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
  v_id   uuid;
begin
  if p_polaroid_id is null then
    insert into polaroids (game_id, title, caption, image_url, sort_order)
    values (
      v_game.id,
      coalesce(p_title, ''),
      coalesce(p_caption, ''),
      p_image_url,
      coalesce(p_sort_order,
        (select coalesce(max(sort_order), 0) + 1 from polaroids where game_id = v_game.id))
    )
    returning id into v_id;
  else
    update polaroids set
      title      = coalesce(p_title, title),
      caption    = coalesce(p_caption, caption),
      image_url  = coalesce(p_image_url, image_url),
      sort_order = coalesce(p_sort_order, sort_order)
    where id = p_polaroid_id and game_id = v_game.id;
    if not found then
      raise exception 'Ukjent polaroid';
    end if;
    v_id := p_polaroid_id;
  end if;

  perform _poke(v_game.id, 'polaroids');
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_delete_polaroid(p_host_token uuid, p_polaroid_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  delete from polaroids where id = p_polaroid_id and game_id = v_game.id;
  if not found then
    raise exception 'Ukjent polaroid';
  end if;

  perform _poke(v_game.id, 'polaroids');
  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- 9) EKSPLISITTE EXECUTE-RETTIGHETER PÅ RPC-ENE
-- ----------------------------------------------------------------------------

grant execute on function create_game() to anon, authenticated;
grant execute on function join_game(text, text) to anon, authenticated;
grant execute on function get_my_player(uuid) to anon, authenticated;
grant execute on function get_public_suspects(uuid) to anon, authenticated;
grant execute on function get_public_polaroids(uuid) to anon, authenticated;
grant execute on function set_suspicion(uuid, uuid, int) to anon, authenticated;
grant execute on function get_my_suspicions(uuid) to anon, authenticated;
grant execute on function get_reveal(uuid) to anon, authenticated;
grant execute on function host_get_game(uuid) to anon, authenticated;
grant execute on function host_list_players(uuid) to anon, authenticated;
grant execute on function host_get_suspects(uuid) to anon, authenticated;
grant execute on function host_get_polaroids(uuid) to anon, authenticated;
grant execute on function host_get_suspicions(uuid) to anon, authenticated;
grant execute on function host_set_phase(uuid, text) to anon, authenticated;
grant execute on function host_set_status(uuid, text) to anon, authenticated;
grant execute on function host_assign_suspect(uuid, uuid, uuid) to anon, authenticated;
grant execute on function host_auto_assign(uuid) to anon, authenticated;
grant execute on function host_reveal_polaroid(uuid, uuid, boolean) to anon, authenticated;
grant execute on function host_update_suspect(uuid, uuid, text, text, text, text, text) to anon, authenticated;
grant execute on function host_upsert_polaroid(uuid, uuid, text, text, text, int) to anon, authenticated;
grant execute on function host_delete_polaroid(uuid, uuid) to anon, authenticated;
