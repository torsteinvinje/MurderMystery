-- ==========================================================================
-- MURDERMYSTERY — KOMPLETT DATABASESKJEMA
--
-- ⚠️  GENERERT FIL — IKKE REDIGER DIREKTE.
--     Lag en ny migrasjon i supabase/migrations/ og kjør: npm run schema:build
--     (CI feiler hvis denne fila ikke er i takt med migrasjonene.)
--
-- HVA DETTE ER
--   Alle migrasjonene i supabase/migrations/ satt sammen i rekkefølge —
--   nøyaktig det en oppdatert database har fått kjørt. Kjør hele fila på en
--   fersk database, så får du samme resultat som en som har fulgt
--   migrasjonene fra dag én.
--
-- HVORDAN LESE DEN
--   Fila kjøres ovenfra og ned, og SENERE definisjoner av samme funksjon
--   ERSTATTER tidligere. Noen funksjoner står derfor flere ganger; det er
--   migrasjonshistorikken, ikke en feil. Indeksen under sier hvilken fil den
--   gjeldende versjonen av hver funksjon kommer fra.
--
-- SIKKERHETSMODELLEN (kortversjonen)
--   • RLS er PÅ for alle tabeller, UTEN policies. Klienten når aldri en
--     tabell direkte.
--   • All tilgang går via SECURITY DEFINER-funksjoner som validerer et
--     hemmelig token og returnerer kun det den kalleren har krav på.
--   • Morderen (is_killer) og oppklaringen (resolution) forlater aldri
--     databasen til en spiller før verten har avslørt — eneste vei ut er
--     get_reveal, som krever spillstatus 'revealed'.
--
-- Generert fra 21 migrasjoner: 00001_init.sql … 00021_everyone_votes.sql
-- ==========================================================================
--
-- INDEKS — gjeldende definisjon av hver funksjon:
--
-- OFFENTLIGE (kallbare via RPC):
--   cast_saboteur_ballot                   00021_everyone_votes.sql
--   claim_saboteur_objective               00011_saboteur_standalone.sql
--   claim_saboteur_task                    00011_saboteur_standalone.sql
--   create_game                            00007_runbooks.sql
--   create_mystery                         00007_runbooks.sql
--   create_saboteur_game                   00011_saboteur_standalone.sql
--   get_my_player                          00001_init.sql
--   get_my_profile                         00005_profile_names.sql
--   get_my_saboteur_brief                  00019_task_and_hint_libraries.sql
--   get_my_saboteur_game_id                00010_saboteur_discovery.sql
--   get_my_saboteur_vote_status            00021_everyone_votes.sql
--   get_my_suspicions                      00001_init.sql
--   get_public_polaroids                   00001_init.sql
--   get_public_suspects                    00001_init.sql
--   get_reveal                             00001_init.sql
--   get_saboteur_ballot_targets            00021_everyone_votes.sql
--   handle_new_user                        00005_profile_names.sql
--   host_add_evidence                      00004_evidence.sql
--   host_add_objective_from_library        00016_saboteur_intro_library.sql
--   host_add_task_from_library             00019_task_and_hint_libraries.sql
--   host_archive_saboteur_game             00011_saboteur_standalone.sql
--   host_assign_suspect                    00001_init.sql
--   host_auto_assign                       00001_init.sql
--   host_auto_assign_roles                 00011_saboteur_standalone.sql
--   host_clear_task_trigger                00017_hint_trigger.sql
--   host_close_voting_round                00011_saboteur_standalone.sql
--   host_create_saboteur_game              00009_saboteur_game.sql
--   host_decide_objective_claim            00017_hint_trigger.sql
--   host_decide_task_claim                 00017_hint_trigger.sql
--   host_delete_announcement               00013_saboteur_pins_phases.sql
--   host_delete_evidence                   00004_evidence.sql
--   host_delete_objective                  00018_delete_objectives_tasks.sql
--   host_delete_polaroid                   00001_init.sql
--   host_delete_task                       00018_delete_objectives_tasks.sql
--   host_end_saboteur_game                 00011_saboteur_standalone.sql
--   host_get_game                          00007_runbooks.sql
--   host_get_polaroids                     00001_init.sql
--   host_get_saboteur_audit                00011_saboteur_standalone.sql
--   host_get_saboteur_game                 00017_hint_trigger.sql
--   host_get_suspects                      00001_init.sql
--   host_get_suspicions                    00001_init.sql
--   host_list_eligible_participants        00009_saboteur_game.sql
--   host_list_evidence                     00004_evidence.sql
--   host_list_players                      00001_init.sql
--   host_list_saboteur_hint_library        00019_task_and_hint_libraries.sql
--   host_open_voting_round                 00011_saboteur_standalone.sql
--   host_publish_announcement              00013_saboteur_pins_phases.sql
--   host_remove_participant                00011_saboteur_standalone.sql
--   host_reveal_polaroid                   00001_init.sql
--   host_reveal_voting_round               00011_saboteur_standalone.sql
--   host_set_announcement_published        00015_announcement_drafts.sql
--   host_set_know_each_other               00011_saboteur_standalone.sql
--   host_set_participant_active            00011_saboteur_standalone.sql
--   host_set_participant_role              00011_saboteur_standalone.sql
--   host_set_participants                  00009_saboteur_game.sql
--   host_set_phase                         00001_init.sql
--   host_set_saboteur_intro                00016_saboteur_intro_library.sql
--   host_set_saboteur_phase                00013_saboteur_pins_phases.sql
--   host_set_saboteur_status               00011_saboteur_standalone.sql
--   host_set_show_leaderboard              00011_saboteur_standalone.sql
--   host_set_status                        00001_init.sql
--   host_update_suspect                    00001_init.sql
--   host_upsert_announcement               00015_announcement_drafts.sql
--   host_upsert_objective                  00016_saboteur_intro_library.sql
--   host_upsert_polaroid                   00001_init.sql
--   host_upsert_task                       00017_hint_trigger.sql
--   join_game                              00014_unique_player_names.sql
--   join_saboteur_game                     00013_saboteur_pins_phases.sql
--   list_mysteries                         00002_mysteries.sql
--   list_saboteur_objective_library        00016_saboteur_intro_library.sql
--   list_saboteur_task_library             00019_task_and_hint_libraries.sql
--   missing_migrations                     00020_migration_tracking.sql
--   owner_claim_saboteur_game              00012_saboteur_account.sql
--   owner_delete_mystery                   00002_mysteries.sql
--   owner_delete_polaroid                  00002_mysteries.sql
--   owner_delete_suspect                   00002_mysteries.sql
--   owner_get_mystery                      00007_runbooks.sql
--   owner_list_saboteur_games              00012_saboteur_account.sql
--   owner_set_killer                       00002_mysteries.sql
--   owner_update_mystery                   00007_runbooks.sql
--   owner_upsert_polaroid                  00002_mysteries.sql
--   owner_upsert_suspect                   00002_mysteries.sql
--   record_migration                       00020_migration_tracking.sql
--   rejoin_saboteur_game                   00013_saboteur_pins_phases.sql
--   set_suspicion                          00001_init.sql
--   update_my_profile                      00005_profile_names.sql
--
-- INTERNE (execute trukket tilbake fra anon/authenticated):
--   _host_game                             00001_init.sql
--   _owner_mystery                         00002_mysteries.sql
--   _player                                00001_init.sql
--   _poke                                  00001_init.sql
--   _saboteur_apply_transition             00011_saboteur_standalone.sql
--   _saboteur_audit                        00011_saboteur_standalone.sql
--   _saboteur_enabled                      00011_saboteur_standalone.sql
--   _saboteur_game_for_host                00009_saboteur_game.sql
--   _saboteur_host                         00011_saboteur_standalone.sql
--   _saboteur_me                           00011_saboteur_standalone.sql
--   _saboteur_participant_for_player       00009_saboteur_game.sql
--   _saboteur_random_participant           00016_saboteur_intro_library.sql
--   _saboteur_release_hint                 00019_task_and_hint_libraries.sql
--
-- ==========================================================================

-- ==========================================================================
-- ▼ 00001_init.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00002_mysteries.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00002 — Flere mysterier (MurderMystery)
--
-- Gjør om appen fra ett innebygd mysterium til en katalog: `mysteries` er
-- maler (med egne mistenkte, mordere og polaroider), og hvert spill kopierer
-- innholdet fra ett mysterium når det opprettes. Forfattere identifiseres med
-- en hemmelig owner_token — samme mønster som host_token/player_token.
--
-- Sikkerhet: mysteries.resolution og mystery_suspects.is_killer er like
-- beskyttet som i spillene — de forlater bare databasen via owner_*-RPC-ene
-- (krever owner_token). Det innebygde mysteriet har en owner_token ingen
-- kjenner, så løsningen der nås kun via vertens spill-RPC-er.
--
-- Trygg å kjøre flere ganger. supabase-schema.sql inneholder samme sluttbilde.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) NYE TABELLER
-- ----------------------------------------------------------------------------

create table if not exists mysteries (
  id          uuid primary key default gen_random_uuid(),
  owner_token uuid not null default gen_random_uuid(), -- hemmelig forfatternøkkel
  is_builtin  boolean not null default false,
  title       text not null,
  intro       text not null default '',
  resolution  text not null default '',                -- BESKYTTET
  created_at  timestamptz not null default now()
);

create table if not exists mystery_suspects (
  id          uuid primary key default gen_random_uuid(),
  mystery_id  uuid not null references mysteries (id) on delete cascade,
  sort_order  int  not null default 0,
  name        text not null,
  tagline     text not null default '',
  public_info text not null default '',
  secret      text not null default '',
  alibi       text not null default '',
  is_killer   boolean not null default false,          -- BESKYTTET
  created_at  timestamptz not null default now()
);

create table if not exists mystery_polaroids (
  id         uuid primary key default gen_random_uuid(),
  mystery_id uuid not null references mysteries (id) on delete cascade,
  sort_order int  not null default 0,
  title      text not null default '',
  caption    text not null default '',
  image_url  text,
  created_at timestamptz not null default now()
);

-- Spillet husker hvilket mysterium det ble laget fra (innholdet er likevel
-- kopiert inn i spillet, så et slettet mysterium ødelegger ingen fest).
alter table games add column if not exists
  mystery_id uuid references mysteries (id) on delete set null;

alter table mysteries         enable row level security;
alter table mystery_suspects  enable row level security;
alter table mystery_polaroids enable row level security;

-- Ingen policies og ingen grants: all tilgang via RPC-ene under.
revoke all on mysteries, mystery_suspects, mystery_polaroids from anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2) FLYTT DET INNEBYGDE MYSTERIET INN I KATALOGEN
-- ----------------------------------------------------------------------------

do $$
declare
  v_id uuid;
begin
  if exists (select 1 from mysteries where is_builtin) then
    return; -- allerede migrert
  end if;

  insert into mysteries (is_builtin, title, intro, resolution) values (
    true,
    'Ljåmordet på grillfesten',
    'Sommerkvelden på Vollan gård begynte med grillos, rabarbrasaft og gjensynsglede — og endte med et lik. Klokka halv ti fant grillmesteren verten selv, Odd Gunnar Vollan (61), bak redskapsskjulet. Ved siden av ham: gårdens gamle ljå. Grinden til tunet har vært lukket hele kvelden. Ingen har kommet, og ingen har gått. Morderen står fortsatt her — med saftglass i hånda. Lensmannen har tatt saken, og ingen forlater festen før den er løst.',
    'Det var Randi Espeland, banksjefen. I årevis hadde hun dekket egne tap ved å «låne» fra kundenes kontoer — og forfalsket Odd Gunnars signatur på lånepapirene til det nye fjøset. Dagen før festen oppdaget Odd Gunnar det, og ga henne frist til mandag: meld deg selv, ellers ringer jeg Økokrim. Under festen ba han henne møte seg bak redskapsskjulet for å gi henne en siste sjanse. Hun tok med lånepapirene for å brenne dem på grillen — og da han snudde ryggen til, grep hun ljåen fra skjulveggen. Alibiet hennes sprakk med ett eneste gjestebilde: klokka 21.12 var kjøkkenet tomt og kaffetrakteren kald. Smalt støvelavtrykk i størrelse 38. Brente lånepapirer med falsk signatur i grillen. Og i notatboka til Odd Gunnar: «RE: frist mandag». RE. Randi Espeland. Sak avsluttet.'
  ) returning id into v_id;

  insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer) values
  (v_id, 1, 'Solveig Vollan', 'Kona på gården',
   'Gift med Odd Gunnar i 34 år. Sto for potetsalaten og smilte til alle hele kvelden — kanskje litt for bredt.',
   'Du fant skilsmissepapirer i skrivebordet til Odd Gunnar forrige uke. Han skulle forlate deg — og ta gården med seg. Du har ikke fortalt det til noen, og du nekter å la noen få vite at ekteskapet var en fasade.',
   'Jeg sto ved langbordet og skjenket rabarbrasaft fra halv ni til kvart på ti. Spør hvem som helst — glassene var aldri tomme.',
   false),
  (v_id, 2, 'Linn Vollan', 'Datteren som kom hjem',
   'Flyttet til Oslo for åtte år siden. Dukket uventet opp på festen — første gang på gården siden jul.',
   'Du skylder 340 000 kroner etter nettpoker. Du kom hjem for å be far om forskudd på arven. Han sa nei — høylytt — bak låven klokka kvart på ni. Flere kan ha hørt dere.',
   'Jeg satt på trappa og røykte og så på solnedgangen. Alene, dessverre. Men jeg hørte musikken hele tiden.',
   false),
  (v_id, 3, 'Birger Brakstad', 'Naboen med grensetvisten',
   'Grunneier på nabogården. Har kranglet med Odd Gunnar om et jorde i tolv år. Kom likevel i år — med hjemmelaget bringebærsaft som fredsgave.',
   'Grensesaken skulle opp i jordskifteretten neste måned, og advokaten din sa rett ut at du kom til å tape alt. Med Odd Gunnar borte stopper hele saken. Du klarer ikke å slutte å tenke på det.',
   'Jeg var borte ved vedstabelen og hentet mer ved til bålpanna. Det tar tid å finne tørr bjørk, vet du.',
   false),
  (v_id, 4, 'Kjell-Arne Mo', 'Gårdsarbeideren',
   'Har jobbet på Vollan gård i ni år. Kjenner hver krok av gården — og vet hvor alt verktøyet henger.',
   'Odd Gunnar ga deg sparken samme morgen. «Effektivisering», sa han. Du har ikke sagt det til noen — kona di tror fortsatt alt er som før. Du var rasende hele dagen.',
   'Jeg grillet maiskolber på den lille grillen på baksiden. Der er det bare meg, som vanlig. Ingen ser gårdsarbeideren før maten er klar.',
   false),
  (v_id, 5, 'Randi Espeland', 'Banksjefen',
   'Banksjef i bygda i femten år. Ordnet lånet da Vollan bygde nytt fjøs. Alltid pen i tøyet, alltid først til å skåle.',
   'Du har «lånt» av kundenes kontoer for å dekke egne tap — og forfalsket Odd Gunnars signatur på lånepapirer. I går oppdaget han det og ga deg frist til mandag med å melde deg selv. Du MÅ få tak i papirene han sitter på, og ingen kan få vite om fristen.',
   'Jeg var på kjøkkenet, satte på kaffetrakteren og ordnet kransekaka. Kjøkkenvinduet vender jo rett mot tunet — jeg så dere alle sammen.',
   true),
  (v_id, 6, 'Petter «Pjokken» Hauge', 'Grillmesteren',
   'Bygdas selvutnevnte grillkonge. Var sammen med Linn på videregående og har aldri helt kommet over det. Det var han som fant Odd Gunnar.',
   'Du så en skikkelse i mørke klær gå mot redskapsskjulet rundt klokka ni. Du tør ikke si det høyt — for da må du innrømme hvor du selv sto: bak låven, der du øvde deg på å be Linn ut igjen.',
   'Grillen, selvfølgelig! En grillmester forlater aldri grillen. Bortsett fra da jeg hentet mer marinade. To minutter, maks. Kanskje fem.',
   false),
  (v_id, 7, 'Ingrid Sæter', 'Veterinæren',
   'Bygdas veterinær. Var på gården så sent som i forrige uke for å se til en halt hoppe.',
   'Rapporten din fra forrige uke skjuler noe: du fant tegn på vanskjøtsel i fjøset, men Odd Gunnar betalte deg for å «runde av» formuleringene. Kommer det ut, mister du lisensen. Du håper inderlig ingen ber om å få se rapporten.',
   'Jeg var nede ved hestehagen og så til hoppa. Dyr merker uro lenge før mennesker, vet du. Hun var rastløs hele kvelden.',
   false),
  (v_id, 8, 'Tormod Lien', 'Den pensjonerte lensmannen',
   'Bygdas lensmann i tretti år, nå pensjonist. Glemmer aldri et ansikt. Odd Gunnars gamle jaktkamerat.',
   'For tjue år siden henla du en sak mot Odd Gunnar om forsikringssvindel — mot at han holdt munn om fyllekjøringen din. Han har «mint deg på det» hver eneste jul siden. Du kom på festen for å be ham slette gjelda en gang for alle.',
   'Jeg satt i fluktstolen ved bålpanna hele kvelden. Gamle knær, unge øyne. Jeg så alt — trodde jeg.',
   false);

  insert into mystery_polaroids (mystery_id, sort_order, title, caption) values
  (v_id, 1, 'Ljåen',
   'Gårdens gamle ljå, funnet ved siden av Odd Gunnar. Skaftet er tørket omhyggelig rent — med en serviett fra festen. Morderen tenkte klart nok til å fjerne spor.'),
  (v_id, 2, 'Fotavtrykk bak skjulet',
   'Et smalt støvelavtrykk i den myke jorda bak redskapsskjulet. Størrelse 38, med fin hæl. Dette er ingen arbeidsstøvel.'),
  (v_id, 3, 'Notatboka til Odd Gunnar',
   'Siste side i notatboka, skrevet med hardt pennetrykk: «RE: frist mandag. Ellers ringer jeg Økokrim.»'),
  (v_id, 4, 'Kjøkkenvinduet kl. 21.12',
   'Et gjestebilde tatt mot tunet klokka 21.12. I bakgrunnen ses kjøkkenvinduet tydelig. Kjøkkenet er tomt — og kaffetrakteren står ikke på.'),
  (v_id, 5, 'Grillen',
   'Noen har brent papirer i grillen etter at maten var ferdig. Ett hjørne overlevde flammene: «...esignatur: Odd Gunnar Voll...» — men håndskriften er ikke hans.'),
  (v_id, 6, 'Veska i gangen',
   'En åpen veske i gangen. Opp av lomma stikker det som ser ut som skilsmissepapirer — med Solveig Vollans navn på.');
end $$;

-- De gamle mal-tabellene er erstattet av mysteries-katalogen.
drop table if exists suspect_templates;
drop table if exists polaroid_templates;
drop table if exists story_template;

-- ----------------------------------------------------------------------------
-- 3) NY create_game: opprett spill fra et valgt mysterium
-- ----------------------------------------------------------------------------

-- Den gamle parameterløse varianten må bort, ellers blir RPC-kallet tvetydig.
drop function if exists create_game();

create or replace function create_game(p_mystery_id uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery  mysteries;
  v_game     games;
  v_code     text;
  v_chars    text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_suspects int;
  v_killers  int;
begin
  -- Uten angitt mysterium: bruk det innebygde (Ljåmordet på grillfesten).
  if p_mystery_id is null then
    select * into v_mystery from mysteries where is_builtin order by created_at limit 1;
  else
    select * into v_mystery from mysteries where id = p_mystery_id;
  end if;
  if v_mystery.id is null then
    raise exception 'Fant ikke mysteriet';
  end if;

  -- Et spillbart mysterium har minst to mistenkte og nøyaktig én morder.
  select count(*), count(*) filter (where is_killer)
    into v_suspects, v_killers
  from mystery_suspects where mystery_id = v_mystery.id;
  if v_suspects < 2 then
    raise exception 'Mysteriet «%» trenger minst to mistenkte før det kan spilles', v_mystery.title;
  end if;
  if v_killers <> 1 then
    raise exception 'Mysteriet «%» må ha nøyaktig én morder (har %)', v_mystery.title, v_killers;
  end if;

  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from games where code = v_code);
  end loop;

  -- Innholdet KOPIERES inn i spillet: verten kan redigere fritt underveis
  -- uten å endre mysteriet, og mysteriet kan slettes uten å knekke fester.
  insert into games (code, mystery_id, title, intro, resolution)
  values (v_code, v_mystery.id, v_mystery.title, v_mystery.intro, v_mystery.resolution)
  returning * into v_game;

  insert into suspects (game_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
  select v_game.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
  from mystery_suspects s
  where s.mystery_id = v_mystery.id;

  insert into polaroids (game_id, sort_order, title, caption, image_url)
  select v_game.id, p.sort_order, p.title, p.caption, p.image_url
  from mystery_polaroids p
  where p.mystery_id = v_mystery.id;

  perform _poke(v_game.id, 'game');

  return json_build_object(
    'game_id', v_game.id,
    'code', v_game.code,
    'host_token', v_game.host_token
  );
end $$;

-- ----------------------------------------------------------------------------
-- 4) KATALOG OG FORFATTER-RPC-ER
-- ----------------------------------------------------------------------------

-- Offentlig katalog. Røper ALDRI løsning, hemmeligheter eller hvem morderen
-- er — bare om mysteriet er klart til å spilles.
create or replace function list_mysteries()
returns json
language plpgsql security definer set search_path = public
as $$
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', m.id,
      'title', m.title,
      'intro', m.intro,
      'is_builtin', m.is_builtin,
      'suspect_count', (select count(*) from mystery_suspects s where s.mystery_id = m.id),
      'polaroid_count', (select count(*) from mystery_polaroids p where p.mystery_id = m.id),
      'ready', (select count(*) from mystery_suspects s where s.mystery_id = m.id) >= 2
           and (select count(*) from mystery_suspects s where s.mystery_id = m.id and s.is_killer) = 1,
      'created_at', m.created_at
    ) order by m.is_builtin desc, m.created_at), '[]'::json)
    from mysteries m
  );
end $$;

-- Intern: slå opp mysteriet bak en forfatternøkkel.
create or replace function _owner_mystery(p_owner_token uuid)
returns mysteries
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries;
begin
  if p_owner_token is null then
    raise exception 'Mangler forfatternøkkel';
  end if;
  select * into v_mystery from mysteries where owner_token = p_owner_token;
  if not found then
    raise exception 'Ugyldig forfatternøkkel — fant ikke mysteriet';
  end if;
  return v_mystery;
end $$;

revoke execute on function _owner_mystery(uuid) from public, anon, authenticated;

-- Nytt mysterium. p_copy_from kan peke på et INNEBYGD mysterium for å bruke
-- det som utgangspunkt — aldri på andres egne mysterier (de er hemmelige).
create or replace function create_mystery(p_title text, p_copy_from uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_title text := trim(coalesce(p_title, ''));
  v_src   mysteries;
  v_new   mysteries;
begin
  if v_title = '' then
    raise exception 'Mysteriet trenger en tittel';
  end if;
  if length(v_title) > 120 then
    raise exception 'Tittelen er for lang (maks 120 tegn)';
  end if;

  if p_copy_from is not null then
    select * into v_src from mysteries where id = p_copy_from and is_builtin;
    if not found then
      raise exception 'Du kan bare kopiere fra de innebygde mysteriene';
    end if;
  end if;

  insert into mysteries (title, intro, resolution)
  values (v_title, coalesce(v_src.intro, ''), coalesce(v_src.resolution, ''))
  returning * into v_new;

  if v_src.id is not null then
    insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
    select v_new.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
    from mystery_suspects s where s.mystery_id = v_src.id;

    insert into mystery_polaroids (mystery_id, sort_order, title, caption, image_url)
    select v_new.id, p.sort_order, p.title, p.caption, p.image_url
    from mystery_polaroids p where p.mystery_id = v_src.id;
  end if;

  return json_build_object(
    'mystery_id', v_new.id,
    'owner_token', v_new.owner_token,
    'title', v_new.title
  );
end $$;

-- Hele mysteriet for forfatteren — inkludert morder og oppklaring.
create or replace function owner_get_mystery(p_owner_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  return json_build_object(
    'mystery', json_build_object(
      'id', v_mystery.id, 'title', v_mystery.title, 'intro', v_mystery.intro,
      'resolution', v_mystery.resolution, 'is_builtin', v_mystery.is_builtin,
      'created_at', v_mystery.created_at
    ),
    'suspects', (
      select coalesce(json_agg(json_build_object(
        'id', s.id, 'sort_order', s.sort_order, 'name', s.name, 'tagline', s.tagline,
        'public_info', s.public_info, 'secret', s.secret, 'alibi', s.alibi,
        'is_killer', s.is_killer
      ) order by s.sort_order), '[]'::json)
      from mystery_suspects s where s.mystery_id = v_mystery.id
    ),
    'polaroids', (
      select coalesce(json_agg(json_build_object(
        'id', p.id, 'sort_order', p.sort_order, 'title', p.title,
        'caption', p.caption, 'image_url', p.image_url
      ) order by p.sort_order), '[]'::json)
      from mystery_polaroids p where p.mystery_id = v_mystery.id
    )
  );
end $$;

create or replace function owner_update_mystery(
  p_owner_token uuid,
  p_title text default null, p_intro text default null, p_resolution text default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  update mysteries set
    title      = coalesce(nullif(trim(p_title), ''), title),
    intro      = coalesce(p_intro, intro),
    resolution = coalesce(p_resolution, resolution)
  where id = v_mystery.id;
  return json_build_object('ok', true);
end $$;

-- Opprett (p_suspect_id = null) eller oppdater en mistenkt i mysteriet.
-- Hvem som er morderen styres KUN av owner_set_killer.
create or replace function owner_upsert_suspect(
  p_owner_token uuid, p_suspect_id uuid default null,
  p_name text default null, p_tagline text default null,
  p_public_info text default null, p_secret text default null,
  p_alibi text default null, p_sort_order int default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
  v_id      uuid;
begin
  if p_suspect_id is null then
    if trim(coalesce(p_name, '')) = '' then
      raise exception 'Den mistenkte trenger et navn';
    end if;
    insert into mystery_suspects (mystery_id, name, tagline, public_info, secret, alibi, sort_order)
    values (
      v_mystery.id, trim(p_name), coalesce(p_tagline, ''), coalesce(p_public_info, ''),
      coalesce(p_secret, ''), coalesce(p_alibi, ''),
      coalesce(p_sort_order,
        (select coalesce(max(sort_order), 0) + 1 from mystery_suspects where mystery_id = v_mystery.id))
    )
    returning id into v_id;
  else
    update mystery_suspects set
      name        = coalesce(nullif(trim(p_name), ''), name),
      tagline     = coalesce(p_tagline, tagline),
      public_info = coalesce(p_public_info, public_info),
      secret      = coalesce(p_secret, secret),
      alibi       = coalesce(p_alibi, alibi),
      sort_order  = coalesce(p_sort_order, sort_order)
    where id = p_suspect_id and mystery_id = v_mystery.id;
    if not found then
      raise exception 'Ukjent mistenkt';
    end if;
    v_id := p_suspect_id;
  end if;

  return json_build_object('ok', true, 'id', v_id);
end $$;

-- Pek ut morderen: nøyaktig én om gangen.
create or replace function owner_set_killer(p_owner_token uuid, p_suspect_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  perform 1 from mystery_suspects where id = p_suspect_id and mystery_id = v_mystery.id;
  if not found then
    raise exception 'Ukjent mistenkt';
  end if;

  update mystery_suspects set is_killer = false
  where mystery_id = v_mystery.id and is_killer;
  update mystery_suspects set is_killer = true
  where id = p_suspect_id;

  return json_build_object('ok', true);
end $$;

create or replace function owner_delete_suspect(p_owner_token uuid, p_suspect_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  delete from mystery_suspects where id = p_suspect_id and mystery_id = v_mystery.id;
  if not found then
    raise exception 'Ukjent mistenkt';
  end if;
  return json_build_object('ok', true);
end $$;

create or replace function owner_upsert_polaroid(
  p_owner_token uuid, p_polaroid_id uuid default null,
  p_title text default null, p_caption text default null,
  p_image_url text default null, p_sort_order int default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
  v_id      uuid;
begin
  if p_polaroid_id is null then
    insert into mystery_polaroids (mystery_id, title, caption, image_url, sort_order)
    values (
      v_mystery.id, coalesce(p_title, ''), coalesce(p_caption, ''), p_image_url,
      coalesce(p_sort_order,
        (select coalesce(max(sort_order), 0) + 1 from mystery_polaroids where mystery_id = v_mystery.id))
    )
    returning id into v_id;
  else
    update mystery_polaroids set
      title      = coalesce(p_title, title),
      caption    = coalesce(p_caption, caption),
      image_url  = coalesce(p_image_url, image_url),
      sort_order = coalesce(p_sort_order, sort_order)
    where id = p_polaroid_id and mystery_id = v_mystery.id;
    if not found then
      raise exception 'Ukjent polaroid';
    end if;
    v_id := p_polaroid_id;
  end if;

  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function owner_delete_polaroid(p_owner_token uuid, p_polaroid_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  delete from mystery_polaroids where id = p_polaroid_id and mystery_id = v_mystery.id;
  if not found then
    raise exception 'Ukjent polaroid';
  end if;
  return json_build_object('ok', true);
end $$;

-- Slett hele mysteriet. Pågående fester overlever: innholdet deres er kopiert.
create or replace function owner_delete_mystery(p_owner_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  if v_mystery.is_builtin then
    raise exception 'Det innebygde mysteriet kan ikke slettes';
  end if;
  delete from mysteries where id = v_mystery.id;
  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- 5) EXECUTE-RETTIGHETER
-- ----------------------------------------------------------------------------

grant execute on function create_game(uuid) to anon, authenticated;
grant execute on function list_mysteries() to anon, authenticated;
grant execute on function create_mystery(text, uuid) to anon, authenticated;
grant execute on function owner_get_mystery(uuid) to anon, authenticated;
grant execute on function owner_update_mystery(uuid, text, text, text) to anon, authenticated;
grant execute on function owner_upsert_suspect(uuid, uuid, text, text, text, text, text, int) to anon, authenticated;
grant execute on function owner_set_killer(uuid, uuid) to anon, authenticated;
grant execute on function owner_delete_suspect(uuid, uuid) to anon, authenticated;
grant execute on function owner_upsert_polaroid(uuid, uuid, text, text, text, int) to anon, authenticated;
grant execute on function owner_delete_polaroid(uuid, uuid) to anon, authenticated;
grant execute on function owner_delete_mystery(uuid) to anon, authenticated;

-- ==========================================================================
-- ▼ 00003_auth.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00003 — Vertskontoer (Supabase Auth, «lag på toppen»)
--
-- Legger til ekte innlogging for verter UTEN å rive ut den fungerende
-- token-modellen: spill og mysterier styres fortsatt av hemmelige tokens i
-- nettleseren, men når en INNLOGGET vert oppretter noe, knyttes det nå også
-- til brukerkontoen (owner_id -> auth.users). Anonyme verter fungerer som før
-- (owner_id blir da null).
--
-- Denne migrasjonen håndterer autentisering (hvem du er). Autorisasjon (hvem
-- som får se/endre hva) håndheves i en senere migrasjon — se planen i README.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) PROFILER — offentlig-trygg utvidelse av auth.users
--    (Vi kopierer ALDRI passord eller tokens hit. Kun visningsnavn o.l.)
-- ----------------------------------------------------------------------------

create table if not exists profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  created_at   timestamptz not null default now()
);

alter table profiles enable row level security;

-- En innlogget bruker kan lese og endre KUN sin egen profil.
drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Ingen INSERT/DELETE-policy: rader opprettes av triggeren under (security
-- definer) og slettes via cascade når brukeren slettes.

-- Opprett en profil automatisk når en ny bruker registrerer seg. Visningsnavnet
-- tas fra metadata klienten sendte ved registrering (raw_user_meta_data).
create or replace function handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ----------------------------------------------------------------------------
-- 2) EIERSKAP — knytt spill og mysterier til en konto (nullbart)
-- ----------------------------------------------------------------------------

alter table games     add column if not exists owner_id uuid references auth.users (id) on delete set null;
alter table mysteries add column if not exists owner_id uuid references auth.users (id) on delete set null;

create index if not exists games_owner_idx     on games (owner_id);
create index if not exists mysteries_owner_idx on mysteries (owner_id);

-- ----------------------------------------------------------------------------
-- 3) Sett owner_id ved opprettelse (auth.uid() virker også i SECURITY DEFINER:
--    den leser innloggingsclaimet fra forespørselen, ikke funksjonens rolle).
--    Anonyme kall gir auth.uid() = null, altså samme oppførsel som før.
-- ----------------------------------------------------------------------------

create or replace function create_game(p_mystery_id uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery  mysteries;
  v_game     games;
  v_code     text;
  v_chars    text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_suspects int;
  v_killers  int;
begin
  if p_mystery_id is null then
    select * into v_mystery from mysteries where is_builtin order by created_at limit 1;
  else
    select * into v_mystery from mysteries where id = p_mystery_id;
  end if;
  if v_mystery.id is null then
    raise exception 'Fant ikke mysteriet';
  end if;

  select count(*), count(*) filter (where is_killer)
    into v_suspects, v_killers
  from mystery_suspects where mystery_id = v_mystery.id;
  if v_suspects < 2 then
    raise exception 'Mysteriet «%» trenger minst to mistenkte før det kan spilles', v_mystery.title;
  end if;
  if v_killers <> 1 then
    raise exception 'Mysteriet «%» må ha nøyaktig én morder (har %)', v_mystery.title, v_killers;
  end if;

  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from games where code = v_code);
  end loop;

  insert into games (code, mystery_id, title, intro, resolution, owner_id)
  values (v_code, v_mystery.id, v_mystery.title, v_mystery.intro, v_mystery.resolution, auth.uid())
  returning * into v_game;

  insert into suspects (game_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
  select v_game.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
  from mystery_suspects s
  where s.mystery_id = v_mystery.id;

  insert into polaroids (game_id, sort_order, title, caption, image_url)
  select v_game.id, p.sort_order, p.title, p.caption, p.image_url
  from mystery_polaroids p
  where p.mystery_id = v_mystery.id;

  perform _poke(v_game.id, 'game');

  return json_build_object(
    'game_id', v_game.id,
    'code', v_game.code,
    'host_token', v_game.host_token
  );
end $$;

create or replace function create_mystery(p_title text, p_copy_from uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_title text := trim(coalesce(p_title, ''));
  v_src   mysteries;
  v_new   mysteries;
begin
  if v_title = '' then
    raise exception 'Mysteriet trenger en tittel';
  end if;
  if length(v_title) > 120 then
    raise exception 'Tittelen er for lang (maks 120 tegn)';
  end if;

  if p_copy_from is not null then
    select * into v_src from mysteries where id = p_copy_from and is_builtin;
    if not found then
      raise exception 'Du kan bare kopiere fra de innebygde mysteriene';
    end if;
  end if;

  insert into mysteries (title, intro, resolution, owner_id)
  values (v_title, coalesce(v_src.intro, ''), coalesce(v_src.resolution, ''), auth.uid())
  returning * into v_new;

  if v_src.id is not null then
    insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
    select v_new.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
    from mystery_suspects s where s.mystery_id = v_src.id;

    insert into mystery_polaroids (mystery_id, sort_order, title, caption, image_url)
    select v_new.id, p.sort_order, p.title, p.caption, p.image_url
    from mystery_polaroids p where p.mystery_id = v_src.id;
  end if;

  return json_build_object(
    'mystery_id', v_new.id,
    'owner_token', v_new.owner_token,
    'title', v_new.title
  );
end $$;

grant execute on function create_game(uuid) to anon, authenticated;
grant execute on function create_mystery(text, uuid) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4) La en innlogget vert hente sin egen profil (til kontosiden).
-- ----------------------------------------------------------------------------

create or replace function get_my_profile()
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row profiles;
begin
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;
  select * into v_row from profiles where id = v_uid;
  return json_build_object(
    'id', v_uid,
    'display_name', coalesce(v_row.display_name, '')
  );
end $$;

grant execute on function get_my_profile() to authenticated;

-- ==========================================================================
-- ▼ 00004_evidence.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00004 — Bevis (Evidence)
--
-- En egen, vertsstyrt bevisboks per fest — atskilt fra polaroidene.
--   * Polaroider = ledetråder verten AVSLØRER for gjestene under spillet.
--   * Bevis      = vertens PRIVATE saksmappe (vises aldri til gjestene).
--
-- Følger nøyaktig samme mønster som resten av modellen: RLS på uten policies,
-- all tilgang via SECURITY DEFINER-RPC-er som validerer host_token. Bevis er
-- knyttet til en fest (game_id); festen er igjen knyttet til en konto via
-- games.owner_id (fase A), så håndhevet konto-eierskap i fase B arver dette.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create table if not exists evidence (
  id          uuid primary key default gen_random_uuid(),
  game_id     uuid not null references games (id) on delete cascade,
  sort_order  int  not null default 0,
  title       text not null default '',
  description text not null default '',
  image_url   text,
  created_at  timestamptz not null default now()
);

create index if not exists evidence_game_idx on evidence (game_id, sort_order);

alter table evidence enable row level security;
-- Ingen policies: klienten når aldri tabellen direkte. Fjern rettigheter for
-- sikkerhets skyld (belte og bukseseler).
revoke all on evidence from anon, authenticated;

-- ----------------------------------------------------------------------------
-- RPC-er (kun vert, validert med host_token via _host_game)
-- ----------------------------------------------------------------------------

create or replace function host_list_evidence(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', e.id, 'sort_order', e.sort_order, 'title', e.title,
      'description', e.description, 'image_url', e.image_url, 'created_at', e.created_at
    ) order by e.sort_order, e.created_at), '[]'::json)
    from evidence e
    where e.game_id = v_game.id
  );
end $$;

create or replace function host_add_evidence(
  p_host_token uuid, p_title text, p_description text default null, p_image_url text default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  games := _host_game(p_host_token);
  v_title text := trim(coalesce(p_title, ''));
  v_id    uuid;
begin
  if v_title = '' then
    raise exception 'Beviset trenger en tittel';
  end if;
  if length(v_title) > 160 then
    raise exception 'Tittelen er for lang (maks 160 tegn)';
  end if;

  insert into evidence (game_id, title, description, image_url, sort_order)
  values (
    v_game.id, v_title, coalesce(p_description, ''), nullif(trim(coalesce(p_image_url, '')), ''),
    (select coalesce(max(sort_order), 0) + 1 from evidence where game_id = v_game.id)
  )
  returning id into v_id;

  perform _poke(v_game.id, 'evidence');
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_delete_evidence(p_host_token uuid, p_evidence_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  delete from evidence where id = p_evidence_id and game_id = v_game.id;
  if not found then
    raise exception 'Ukjent bevis';
  end if;

  perform _poke(v_game.id, 'evidence');
  return json_build_object('ok', true);
end $$;

grant execute on function host_list_evidence(uuid) to anon, authenticated;
grant execute on function host_add_evidence(uuid, text, text, text) to anon, authenticated;
grant execute on function host_delete_evidence(uuid, uuid) to anon, authenticated;

-- ==========================================================================
-- ▼ 00005_profile_names.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00005 — Fornavn og etternavn på profilen
--
-- Deler visningsnavnet i fornavn + etternavn, og lar en innlogget vert endre
-- navnet sitt. display_name beholdes (utledet som «Fornavn Etternavn») og er
-- det som vises f.eks. øverst til høyre i menyen.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

alter table profiles add column if not exists first_name text not null default '';
alter table profiles add column if not exists last_name  text not null default '';

-- Opprett profil ved registrering: hent fornavn/etternavn fra metadata og bygg
-- display_name. Faller tilbake til et evt. eldre display_name-metadatafelt.
create or replace function handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_first text := coalesce(new.raw_user_meta_data ->> 'first_name', '');
  v_last  text := coalesce(new.raw_user_meta_data ->> 'last_name', '');
begin
  insert into public.profiles (id, first_name, last_name, display_name)
  values (
    new.id, v_first, v_last,
    coalesce(
      nullif(trim(v_first || ' ' || v_last), ''),
      new.raw_user_meta_data ->> 'display_name',
      ''
    )
  )
  on conflict (id) do nothing;
  return new;
end $$;

-- Profilen til den innloggede verten (til kontosiden + menyen).
create or replace function get_my_profile()
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row profiles;
begin
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;
  select * into v_row from profiles where id = v_uid;
  return json_build_object(
    'id', v_uid,
    'first_name', coalesce(v_row.first_name, ''),
    'last_name', coalesce(v_row.last_name, ''),
    'display_name', coalesce(v_row.display_name, '')
  );
end $$;

-- La verten oppdatere navnet sitt (fornavn + etternavn).
create or replace function update_my_profile(p_first text, p_last text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_first text := trim(coalesce(p_first, ''));
  v_last  text := trim(coalesce(p_last, ''));
begin
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;
  if v_first = '' or v_last = '' then
    raise exception 'Fyll inn både fornavn og etternavn';
  end if;
  if length(v_first) > 60 or length(v_last) > 60 then
    raise exception 'Navnet er for langt (maks 60 tegn per felt)';
  end if;

  update profiles
     set first_name = v_first, last_name = v_last,
         display_name = trim(v_first || ' ' || v_last)
   where id = v_uid;

  if not found then
    insert into profiles (id, first_name, last_name, display_name)
    values (v_uid, v_first, v_last, trim(v_first || ' ' || v_last));
  end if;

  return json_build_object('ok', true, 'display_name', trim(v_first || ' ' || v_last));
end $$;

grant execute on function get_my_profile() to authenticated;
grant execute on function update_my_profile(text, text) to authenticated;

-- ==========================================================================
-- ▼ 00006_two_new_mysteries.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00006 — To nye innebygde mysterier
--
--   * «Giftmordet på julebordet»  — firmajulebord, gift i akevitten
--   * «Drapet på HR-sjefen»       — firmafest under nedbemanning
--
-- Begge er bygget rundt det FYSISKE opplegget (se runbooks/-mappen i repoet):
-- offeret gjør en entré og dør foran gjestene, festen fortsetter, og
-- polaroidene er ekte utskrevne bilder verten har iscenesatt på forhånd.
-- Polaroidene her i databasen er vertens digitale backup av de samme bevisene.
--
-- Struktur per mysterium (samme dramaturgi som Ljåmordet-festen):
--   1) Entré og død  2) Presentasjon av de mistenkte  3) Utspørring mens
--   festen går  4) Tippetimen åpner  5) Polaroid-avsløring som FLYTTER
--   åstedet  6) Løsning der et fysisk spor knuser ett alibi.
--
-- Trygg å kjøre flere ganger (hvert mysterium seedes bare hvis det mangler).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- GIFTMORDET PÅ JULEBORDET
-- ----------------------------------------------------------------------------
do $$
declare
  v_id uuid;
begin
  if exists (select 1 from mysteries where is_builtin and title = 'Giftmordet på julebordet') then
    return;
  end if;

  insert into mysteries (is_builtin, title, intro, resolution) values (
    true,
    'Giftmordet på julebordet',
    'Julebordet til Solli & Sønner Rørleggerservice var i full gang med pinnekjøtt, firmaquiz og akevitt da grunnleggeren selv, Arvid Solli (68), reiste seg for å holde sin berømte tale. I år skulle han endelig kunngjøre hvem som tar over firmaet. Han rakk aldri så langt. Midt i skålen tok han seg til halsen, veltet glasset og segnet om over langbordet. Glasset luktet bittert. Ingen utenfra har vært i lokalet i kveld — den som forgiftet Arvid, sitter fortsatt til bords. Og julebordet? Det fortsetter som planlagt. Morderen skal ingen steder.',
    'Det var Camilla Solli-Berg, datteren og økonomisjefen. I to år hadde hun dekket skjulte lån med penger fra firmakontoen, og på nyåret ventet full gjennomgang hos revisor — bestilt av faren selv. Camilla visste det alle i familien visste: Arvid rørte aldri felleskaraffelen på bordet. Han skjenket bare fra sin egen karaffel på kjøkkenet. Der la hun giften, trygg på at bare faren ville få den i glasset. Men hun gjorde to feil. Hun tråkket i melisen som ble sølt da riskremen ble pyntet — ett smalt hælavtrykk, fra sko ingen andre på kjøkkenet gikk med. Og hun la sitt eget bordkort som brikke under karaffelen mens hun helte. «Jeg reiste meg aldri fra bordet», sa hun. Melisen og bordkortet sier noe annet. Beste begrunnelse vinner — ikke bare riktig navn.'
  ) returning id into v_id;

  insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer) values
  (v_id, 1, 'Bjørnar Solli', 'Eldstesønnen og driftslederen',
   'Har jobbet i firmaet i tjue år og omtaler seg selv som «neste generasjon Solli». Holdt en lang og selvsikker skål tidligere i kveld.',
   'Faren tok deg til side i går og sa at du IKKE får overta firmaet — «du drikker for mye, gutt». Du har ikke fortalt det til noen. I ren trass kastet du lommelerka di ut i snøen bak huset da du kom i kveld — og du angrer allerede.',
   'Jeg sto ved punsjbollen og skjenket for folk nesten hele kvelden. Spør hvem som helst — jeg var aldri på kjøkkenet.',
   false),
  (v_id, 2, 'Camilla Solli-Berg', 'Datteren og økonomisjefen',
   'Styrer alt av tall i firmaet, og i kveld også poengene i firmaquizen. Satt ved langbordet med skjemaet foran seg hele kvelden.',
   'Du har «lånt» av firmakontoen i to år for å dekke lån ingen kjenner til. Faren har bestilt full gjennomgang hos revisoren på nyåret. I kveld MÅ du fremstå som den rolige og ansvarlige i familien.',
   'Jeg satt ved bordet og førte quizpoeng fra vi satte oss. Jeg reiste meg ikke en eneste gang før talen.',
   true),
  (v_id, 3, 'Lillian Solli', 'Kona og julebordsgeneralen',
   'Har laget maten til julebordet i førti år. Gikk ut og inn av kjøkkenet hele kvelden — som alltid.',
   'Du overhørte Arvid i telefonen forrige uke: han planla å selge firmaet til Rørcompaniet og flytte til Spania — uten å spørre deg. Dere kranglet så det haglet, og naboen kan ha hørt alt.',
   'Selvfølgelig var jeg på kjøkkenet — noen må passe pinnekjøttet og pynte riskremen. Men akevitten hans har jeg aldri fått lov til å røre.',
   false),
  (v_id, 4, 'Roger «Rusken» Myhre', 'Verksmesteren og førstelærlingen',
   'Arvids aller første lærling, femogtredve år i firmaet. Kjenner Arvids vaner bedre enn noen — også hvor han gjemmer den gode akevitten.',
   'Du så noen smette ut fra kjøkkenet med noe blankt i hånden rett før talen. Men du tør ikke si det høyt — for da må du innrømme hvor du sto: i bakgangen, med lommelerka du fant i snøen.',
   'Jeg var ute i røykeskuret. Kalde fingre, god samvittighet.',
   false),
  (v_id, 5, 'Trude Vang', 'Lærlingen og gulljenta',
   'Nyutdannet og allerede Arvids favoritt. Fikk ansvar for musikken i kveld og har styrt spillelisten fra anlegget.',
   'Arvid fortalte deg i forrige uke at det er DEG han vil utnevne til daglig leder — «familien kommer til å rase, men firmaet trenger deg». Du har allerede fortalt det til banken for å få boliglån.',
   'Jeg sto ved musikkanlegget. Noen måtte redde festen fra familien Sollis spilleliste.',
   false);

  insert into mystery_polaroids (mystery_id, sort_order, title, caption) values
  (v_id, 1, 'Karaffelen på kjøkkenet',
   'Giften var ikke i glasset på bordet. Arvids private akevittkaraffel — den ingen andre får røre — står fremme på kjøkkenbenken. I bunnen: et grønnlig slam som ikke er krydder. Den som la gift her, visste nøyaktig hvem som kom til å drikke.'),
  (v_id, 2, 'Melisen på gulvet',
   'Da riskremen ble pyntet, ble det sølt melis på kjøkkengulvet. I melisen: ett tydelig, smalt hælavtrykk på vei mot benken. Ingen som var på kjøkkenet i kveld, gikk med smale hæler. Eller?'),
  (v_id, 3, 'Bordkortet',
   'Under karaffelen ligger et bordkort fra langbordet, brukt som brikke. Våt ring etter karaffelbunnen. Navnet på kortet: Camilla.'),
  (v_id, 4, 'Lommelerka i snøen',
   'En sølvfarget lommelerke ligger kastet i snøen utenfor bakdøren, gravert «B.S.». Hvem kaster en full lommelerke — og hvorfor akkurat i kveld?');
end $$;

-- ----------------------------------------------------------------------------
-- DRAPET PÅ HR-SJEFEN
-- ----------------------------------------------------------------------------
do $$
declare
  v_id uuid;
begin
  if exists (select 1 from mysteries where is_builtin and title = 'Drapet på HR-sjefen') then
    return;
  end if;

  insert into mysteries (is_builtin, title, intro, resolution) values (
    true,
    'Drapet på HR-sjefen',
    'Stemningen på firmafesten til Klyve & Ko var allerede anspent — midt i nedbemanningen «Prosjekt Slank Organisasjon» — da HR-sjef Wenche Wold (51) skålte for «en spennende omstilling for oss alle». Senere på kvelden raver hun inn fra gangen med sitt eget nøkkelkortbånd stramt rundt halsen, griper etter en krøllete utskrift og segner om foran hele festen. Arket er forsiden av nedbemanningslisten. Resten mangler. Dørene har kodelås, og ingen utenfra har vært inne. Morderen står blant kollegene — og festen fortsetter. Ingen går hjem før dette er løst.',
    'Det var Nadia Haug, protesjeen. Wenche hadde selv løftet henne frem — helt til det kom et brev fra universitetet som bekreftet at mastergraden på CV-en aldri ble fullført. Wenche tok henne med ned i arkivet for «en tøff, men rettferdig samtale» og la brevet på bordet: innrøm alt mandag morgen, ellers gjør jeg det. For Nadia var det slutten på alt hun hadde bygget. Hun grep nøkkelkortbåndet som lå på arkivskapet og strammet til. Etterpå prøvde hun å makulere brevet, men maskinen satte seg fast halvveis. Så stilte hun seg på terrassen med hånden mot øret og «en viktig kundesamtale». Én detalj felte henne: telefonen hennes lå til lading ved miksepulten hele kvelden — midt i bakgrunnen på festbildet tatt 21.40. Man tar ikke kundesamtaler uten telefon. Beste begrunnelse vinner — ikke bare riktig navn.'
  ) returning id into v_id;

  insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer) values
  (v_id, 1, 'Steinar Brekke', 'Mellomlederen på oppsigelseslisten',
   'Tjuefem år i firmaet, leder for avdelingen alle vet skal «effektiviseres». Har stått ved bufféten i kveld med et smil som ikke når øynene.',
   'Wenche fortalte deg på tomannshånd i forrige uke at du står øverst på listen. Du har ikke sagt det til kona. Og du sendte Wenche en rasende e-post du angrer bittert på: «Dette skal du få igjen.»',
   'Jeg har stått ved bufféten hele kvelden og sørget for at folk forsyner seg. Må jo gjøre nytte for meg — mens jeg ennå kan.',
   false),
  (v_id, 2, 'Nadia Haug', 'Konsulenten og protesjeen',
   'Firmaets stigende stjerne, håndplukket av Wenche selv. Alltid på, alltid tilgjengelig — hun tok visstnok en kundesamtale midt under festen.',
   'Mastergraden på CV-en din ble aldri fullført. Et brev fra universitetet er på vei gjennom systemet, og du mistenker at Wenche allerede har lest det. Alt du har bygget, står og faller på at ingen får vite det.',
   'Jeg sto på terrassen og tok en lang kundesamtale. Kundene i Singapore bryr seg ikke om at vi har fest.',
   true),
  (v_id, 3, 'Kjartan Moe', 'Tillitsvalgt og alles venn',
   'Tillitsvalgt i tjue år. Har gått fra gruppe til gruppe hele kvelden og forsikret alle om at «ingen skal stå alene i dette».',
   'Du har i hemmelighet forhandlet frem en avtale som freder DIN stilling — mot at du «bidrar til ro» rundt nedbemanningen. Avtalen ligger signert i arkivet. Kommer den ut, er du ferdig som tillitsvalgt.',
   'Jeg har vært overalt og ingen steder, slik en tillitsvalgt skal. Spør hvem som helst — jeg har snakket med alle.',
   false),
  (v_id, 4, 'Benedikte Klyve', 'Daglig leder og arvingen',
   'Tredje generasjon Klyve. Det er hun som har bestilt nedbemanningen — «en nødvendig trimming», som hun kaller det i talene sine.',
   'Firmaet blør penger fordi DU har tømt det gjennom et konsulentprosjekt som aldri fantes. Wenche fant det i tallene og sa: «Rører du mine folk, går jeg til styret.» Nedbemanningslisten var deres dragkamp — og du var i ferd med å tape.',
   'Jeg satt i baren og finpusset talen min. En leder må levere, også på fest.',
   false),
  (v_id, 5, 'Jonas Lie-Pettersen', 'IT-ansvarlig og festens DJ',
   'Styrer alt fra nøkkelkort til spilleliste. Har sittet ved miksepulten hele kvelden og tatt bilder til intranettet.',
   'Du har lest e-poster du aldri skulle lest — deriblant et brev fra et universitet om mastergraden til en kollega. Du har ikke sagt det til noen, for da må du forklare hvordan du fikk tak i det.',
   'Jeg har sittet ved miksepulten hele kvelden. Musikk, bilder, ladestasjon — alt skjer hos meg.',
   false);

  insert into mystery_polaroids (mystery_id, sort_order, title, caption) values
  (v_id, 1, 'Arkivet i kjelleren',
   'Det skjedde ikke i gangen. I arkivet i kjelleren: en veltet stol, Wenches lesebriller på gulvet og en åpen skuff merket «Personal — konfidensielt». Én mappe ligger igjen, tom: «CV-verifisering».'),
  (v_id, 2, 'Makuleringsmaskinen',
   'Noen prøvde å makulere et brev i all hast, men maskinen satte seg fast halvveis. Øverst på det halvt oppspiste arket kan man fremdeles lese: «...bekrefter at kandidaten ikke fullførte mastergraden...».'),
  (v_id, 3, 'Festbildet kl. 21.40',
   'Jonas sitt bilde fra miksepulten, tatt 21.40. I bakgrunnen, tydelig i ladestasjonen: en telefon med glitrende deksel. Alle vet hvem den tilhører. Hvem tar en lang kundesamtale uten telefonen sin?'),
  (v_id, 4, 'Avtalen i dressjakka',
   'Et sammenbrettet dokument stikker opp av lommen på en dressjakke hengt over en stol: «Avtale om fredning av stilling — konfidensielt». Signert Wenche Wold og … Kjartan Moe.');
end $$;

-- ==========================================================================
-- ▼ 00007_runbooks.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00007 — Kjøreplan (runbook) i appen
--
-- Hvert mysterium får en kjøreplan: regi, rekvisitter og tidslinje for det
-- fysiske opplegget. Den kopieres inn i spillet ved opprettelse (som alt
-- annet innhold), vises KUN i vertens Regi-fane, og kan redigeres i
-- verkstedet.
--
-- SIKKERHET: kjøreplanen inneholder løsningen. Den går bare ut via
-- host_get_game (host_token) og owner_get_mystery (owner_token) — aldri via
-- spiller-RPC-ene eller list_mysteries. Kolonne-grants på games er uendret
-- (runbook er ikke med i SELECT-listen som er innvilget klientroller).
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

alter table mysteries add column if not exists runbook text not null default '';
alter table games     add column if not exists runbook text not null default '';

-- ----------------------------------------------------------------------------
-- Oppdaterte funksjoner (kopier runbook / eksponer den for vert og forfatter)
-- ----------------------------------------------------------------------------

create or replace function create_game(p_mystery_id uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery  mysteries;
  v_game     games;
  v_code     text;
  v_chars    text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_suspects int;
  v_killers  int;
begin
  if p_mystery_id is null then
    select * into v_mystery from mysteries where is_builtin order by created_at limit 1;
  else
    select * into v_mystery from mysteries where id = p_mystery_id;
  end if;
  if v_mystery.id is null then
    raise exception 'Fant ikke mysteriet';
  end if;

  select count(*), count(*) filter (where is_killer)
    into v_suspects, v_killers
  from mystery_suspects where mystery_id = v_mystery.id;
  if v_suspects < 2 then
    raise exception 'Mysteriet «%» trenger minst to mistenkte før det kan spilles', v_mystery.title;
  end if;
  if v_killers <> 1 then
    raise exception 'Mysteriet «%» må ha nøyaktig én morder (har %)', v_mystery.title, v_killers;
  end if;

  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from games where code = v_code);
  end loop;

  insert into games (code, mystery_id, title, intro, resolution, runbook, owner_id)
  values (v_code, v_mystery.id, v_mystery.title, v_mystery.intro, v_mystery.resolution,
          coalesce(v_mystery.runbook, ''), auth.uid())
  returning * into v_game;

  insert into suspects (game_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
  select v_game.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
  from mystery_suspects s
  where s.mystery_id = v_mystery.id;

  insert into polaroids (game_id, sort_order, title, caption, image_url)
  select v_game.id, p.sort_order, p.title, p.caption, p.image_url
  from mystery_polaroids p
  where p.mystery_id = v_mystery.id;

  perform _poke(v_game.id, 'game');

  return json_build_object(
    'game_id', v_game.id,
    'code', v_game.code,
    'host_token', v_game.host_token
  );
end $$;

create or replace function create_mystery(p_title text, p_copy_from uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_title text := trim(coalesce(p_title, ''));
  v_src   mysteries;
  v_new   mysteries;
begin
  if v_title = '' then
    raise exception 'Mysteriet trenger en tittel';
  end if;
  if length(v_title) > 120 then
    raise exception 'Tittelen er for lang (maks 120 tegn)';
  end if;

  if p_copy_from is not null then
    select * into v_src from mysteries where id = p_copy_from and is_builtin;
    if not found then
      raise exception 'Du kan bare kopiere fra de innebygde mysteriene';
    end if;
  end if;

  insert into mysteries (title, intro, resolution, runbook, owner_id)
  values (v_title, coalesce(v_src.intro, ''), coalesce(v_src.resolution, ''),
          coalesce(v_src.runbook, ''), auth.uid())
  returning * into v_new;

  if v_src.id is not null then
    insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
    select v_new.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
    from mystery_suspects s where s.mystery_id = v_src.id;

    insert into mystery_polaroids (mystery_id, sort_order, title, caption, image_url)
    select v_new.id, p.sort_order, p.title, p.caption, p.image_url
    from mystery_polaroids p where p.mystery_id = v_src.id;
  end if;

  return json_build_object(
    'mystery_id', v_new.id,
    'owner_token', v_new.owner_token,
    'title', v_new.title
  );
end $$;

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
    'resolution', v_game.resolution, 'runbook', coalesce(v_game.runbook, ''),
    'created_at', v_game.created_at
  );
end $$;

create or replace function owner_get_mystery(p_owner_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  return json_build_object(
    'mystery', json_build_object(
      'id', v_mystery.id, 'title', v_mystery.title, 'intro', v_mystery.intro,
      'resolution', v_mystery.resolution, 'runbook', coalesce(v_mystery.runbook, ''),
      'is_builtin', v_mystery.is_builtin, 'created_at', v_mystery.created_at
    ),
    'suspects', (
      select coalesce(json_agg(json_build_object(
        'id', s.id, 'sort_order', s.sort_order, 'name', s.name, 'tagline', s.tagline,
        'public_info', s.public_info, 'secret', s.secret, 'alibi', s.alibi,
        'is_killer', s.is_killer
      ) order by s.sort_order), '[]'::json)
      from mystery_suspects s where s.mystery_id = v_mystery.id
    ),
    'polaroids', (
      select coalesce(json_agg(json_build_object(
        'id', p.id, 'sort_order', p.sort_order, 'title', p.title,
        'caption', p.caption, 'image_url', p.image_url
      ) order by p.sort_order), '[]'::json)
      from mystery_polaroids p where p.mystery_id = v_mystery.id
    )
  );
end $$;

-- Ny signatur (med p_runbook): den gamle må bort først, ellers blir kallet
-- tvetydig for PostgREST.
drop function if exists owner_update_mystery(uuid, text, text, text);

create or replace function owner_update_mystery(
  p_owner_token uuid,
  p_title text default null, p_intro text default null,
  p_resolution text default null, p_runbook text default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery mysteries := _owner_mystery(p_owner_token);
begin
  update mysteries set
    title      = coalesce(nullif(trim(p_title), ''), title),
    intro      = coalesce(p_intro, intro),
    resolution = coalesce(p_resolution, resolution),
    runbook    = coalesce(p_runbook, runbook)
  where id = v_mystery.id;
  return json_build_object('ok', true);
end $$;

grant execute on function owner_update_mystery(uuid, text, text, text, text) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Kjøreplaner for de innebygde mysteriene (settes bare hvis feltet er tomt,
-- så en vert som har redigert sin egen tekst ikke får den overskrevet).
-- ----------------------------------------------------------------------------

update mysteries set runbook =
'REKVISITTER
- Hvit skjorte med teaterblod og en falsk ljå limt/teipet på ryggen
- De 6 polaroidene printet på forhånd (motivene står i Polaroider-fanen)
- Tippelapper, penner og en bolle til innlevering

PRESENTASJON — START
- Odd Gunnar raver inn på tunet med ljåen i ryggen og segner om foran gjestene
- Du tar kommando og roer gjestene: les åstedsrapporten høyt fra appen
- Presenter de mistenkte én og én — hver sier hvem de er og leser alibiet sitt

UTSPØRRINGEN — FESTEN FORTSETTER SOM FØR
- Gjestene stiller spørsmål til de mistenkte
- De mistenkte svarer fra rollekortene sine — ikke noe mer
- App: sett fasen til «Etterforskningen»

TIPPETIMEN ÅPNES
- «Den neste timen kan dere tippe hvem morderen er»
- Navn + begrunnelse på lapp — men ikke lever inn ennå
- Gjestene mingler, diskuterer og forhører videre

POLAROID-AVSLØRINGEN — CA. 15 MIN INN I TIPPETIMEN
- Avbryt musikken og vis polaroidene én og én, les dem høyt
- Spar kjøkkenvinduet kl. 21.12 til slutt
- La gjestene koble selv: hvem sa hun var på kjøkkenet hele kvelden?
- App: avslør de samme polaroidene i Polaroider-fanen

LØSNINGEN — TIPPETIMEN SLUTT
- Tippelappene leveres inn og leses opp med begrunnelser
- Avslør: Randi sa hun var på kjøkkenet — men kl. 21.12 var kjøkkenet tomt og
  kaffetrakteren kald. Smalt avtrykk i størrelse 38. «RE: frist mandag.»
- Randi bryter sammen. Beste begrunnelse vinner — ikke bare riktig navn!
- App: trykk den røde knappen, så får alle oppklaringen på telefonen'
where is_builtin and title = 'Ljåmordet på grillfesten' and runbook = '';

update mysteries set runbook =
'REKVISITTER
- Akevittglass til talen + «Arvids private» karaffel med grønt pulver i bunnen
  (sukker + konditorfarge)
- Melis til gulvsølet, bordkort til alle mistenkte, sølvfarget lommelerke («B.S.»)
- De 4 polaroidene printet på forhånd:
  1) Karaffelen med grønt slam  2) Melis på gulv med ETT smalt hælavtrykk
  3) Camillas bordkort under karaffelen (våt ring)  4) Lommelerka i snøen
- Tippelapper, penner og en bolle

PRESENTASJON — START
- Arvid reiser seg til tale: «I år skal dere få vite hvem som tar over …»
- Han skåler, griper seg til halsen, velter glasset og segner om over bordet
- Du tar kommando: les åstedsrapporten høyt. «Julebordet fortsetter!»
- Presenter de 5 mistenkte én og én — hver leser alibiet sitt

UTSPØRRINGEN — FESTEN FORTSETTER SOM FØR
- Gjestene forhører de mistenkte ved bordet og i baren
- De mistenkte svarer fra rollekortene — ikke noe mer
- App: sett fasen til «Etterforskningen»

TIPPETIMEN ÅPNES
- «Den neste timen kan dere tippe hvem morderen er» — lapp med navn + begrunnelse

POLAROID-AVSLØRINGEN — CA. 15 MIN INN I TIPPETIMEN
- «Giften var ikke i glasset på bordet. Den var i karaffelen på KJØKKENET.»
- Vis karaffelen først — alle ser på Lillian (hun er uskyldig!)
- Så melisen og bordkortet. La gjestene koble selv: hvem sa hun aldri reiste
  seg fra bordet? Lommelerka er ekstra støy
- App: avslør de samme polaroidene i Polaroider-fanen

LØSNINGEN — TIPPETIMEN SLUTT
- Lappene leses opp med begrunnelser
- Avslør: Camillas bordkort lå under karaffelen, hælavtrykket er hennes
- Camilla bryter sammen. Beste begrunnelse vinner — ikke bare riktig navn!
- App: trykk den røde knappen'
where is_builtin and title = 'Giftmordet på julebordet' and runbook = '';

update mysteries set runbook =
'REKVISITTER
- Nøkkelkortbånd (lanyard) med ID-kort — drapsvåpenet rundt halsen på Wenche
- Krøllete utskrift: «NEDBEMANNINGSLISTEN — KONFIDENSIELT» (bare forsiden)
- De 4 polaroidene printet på forhånd:
  1) Arkivet: veltet stol, lesebriller, tom mappe «CV-verifisering»
  2) Halvmakulert brev: «...bekrefter at kandidaten ikke fullførte mastergraden...»
  3) «Festbilde kl. 21.40» med glittertelefon på lading ved miksepulten
  4) «Fredningsavtale» som stikker opp av en dressjakkelomme
- Tippelapper, penner og en bolle

PRESENTASJON — START
- Wenche skåler for «en spennende omstilling», forsvinner ut — og raver ti
  minutter senere inn med båndet stramt rundt halsen og listen i hånden
- Du tar kommando: les åstedsrapporten. «Ingen går hjem — men baren er åpen»
- Presenter de 5 mistenkte én og én — hver leser alibiet sitt

UTSPØRRINGEN — FESTEN FORTSETTER SOM FØR
- Gjestene forhører de mistenkte i smågrupper
- App: sett fasen til «Etterforskningen»

TIPPETIMEN ÅPNES
- «Den neste timen kan dere tippe hvem morderen er» — lapp med navn + begrunnelse

POLAROID-AVSLØRINGEN — CA. 15 MIN INN I TIPPETIMEN
- «Det skjedde ikke i gangen. Det skjedde i ARKIVET i kjelleren.»
- Vis arkivet, så makuleringsmaskinen, så avtalen (alle ser på Kjartan — feil!)
- Til slutt festbildet: hvem tar kundesamtale uten telefonen sin?
- App: avslør de samme polaroidene i Polaroider-fanen

LØSNINGEN — TIPPETIMEN SLUTT
- Lappene leses opp med begrunnelser
- Avslør: Nadia sto «i telefonen på terrassen» — mens telefonen lå på lading
  ved miksepulten. Brevet i makulatoren var CV-dommen hennes
- Nadia bryter sammen. Beste begrunnelse vinner — ikke bare riktig navn!
- App: trykk den røde knappen'
where is_builtin and title = 'Drapet på HR-sjefen' and runbook = '';

-- ==========================================================================
-- ▼ 00008_remove_evidence.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00008 — Fjern den separate «Bevis»/Evidence-funksjonen
--
-- «Polaroider» heter nå «Bevis» i grensesnittet, så den egne evidence-fanen
-- er overflødig. Denne migrasjonen fjerner den fra databasen.
--
-- OBS: dette sletter evidence-tabellen og alt innhold i den. Det er meningen —
-- funksjonen er tatt ut. Polaroidene (som nå heter «Bevis») er en egen tabell
-- og røres ikke.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

drop function if exists host_list_evidence(uuid);
drop function if exists host_add_evidence(uuid, text, text, text);
drop function if exists host_delete_evidence(uuid, uuid);

drop table if exists evidence;

-- ==========================================================================
-- ▼ 00009_saboteur_game.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00010_saboteur_discovery.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00010 — Skjult agenda: spillerens oppdagelses-RPC
--
-- Gap found while wiring the player view: the HOST gets a saboteur_game_id
-- back from host_create_saboteur_game and can store it locally. A PLAYER has
-- no such id to start from — their phone only has a player_token. This RPC
-- lets a player's own device discover "is there a (non-archived) Skjult
-- agenda for my party, and what's its id" so it can then call
-- get_my_saboteur_brief with that id.
--
-- Safe to expose: it reveals only that a saboteur_game exists for the
-- caller's OWN party (same non-sensitive class of fact as "this party has a
-- murder-mystery running") — no role, no participant list, no objectives,
-- no votes. Whether the caller is actually a participant is still decided
-- entirely by get_my_saboteur_brief afterward, via the existing
-- _saboteur_participant_for_player guard.
--
-- Idempotent (safe to re-run).
-- ============================================================================

create or replace function get_my_saboteur_game_id(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players;
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then
    raise exception 'Skjult agenda er ikke slått på';
  end if;
  v_player := _player(p_player_token);

  select * into v_sabgame from saboteur_games
  where game_id = v_player.game_id and status <> 'archived'
  order by created_at desc
  limit 1;

  return json_build_object('saboteur_game_id', v_sabgame.id);
end $$;

grant execute on function get_my_saboteur_game_id(uuid) to anon, authenticated;

-- ==========================================================================
-- ▼ 00011_saboteur_standalone.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00012_saboteur_account.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00012 — Skjult agenda: knytt spill til vertskontoen
--
-- Problemet dette løser: vertsnøkkelen har bare ligget i localStorage. Bytter
-- verten telefon, tømmer nettleseren eller åpner spillet i inkognito, er
-- spillet borte for godt — selv om det står og går fint i databasen.
--
-- Med innlogging får verten samme opplevelse som resten av appen: spillene
-- dine følger kontoen din, ikke enheten. create_saboteur_game setter allerede
-- owner_id = auth.uid() (fra 00011), så det som mangler er å kunne LISTE og
-- GJENOPPTA dem — pluss å kunne knytte til et spill man laget før man logget inn.
--
-- Sikkerhet:
--   - Begge funksjonene krever innlogging (auth.uid() må finnes).
--   - owner_list_saboteur_games returnerer KUN rader der owner_id = auth.uid().
--     Den returnerer host_token for disse — det er trygt, for det er nettopp
--     verten sitt eget spill; nøkkelen er den samme de allerede hadde lokalt.
--   - owner_claim_saboteur_game krever at du oppgir host_token. Den som har
--     vertsnøkkelen kontrollerer allerede spillet fullt ut, så å la dem knytte
--     det til egen konto gir ingen ny tilgang. Et spill som allerede eies av
--     en ANNEN konto kan ikke overtas.
--   - Som alt annet her: funksjonsflagget sjekkes først.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- Mine Skjult agenda-spill (krever innlogging).
create or replace function owner_list_saboteur_games()
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;

  return (
    select coalesce(json_agg(json_build_object(
      'saboteur_game_id', g.id,
      'code', g.code,
      'title', g.title,
      'status', g.status,
      'host_token', g.host_token,
      'participant_count', (select count(*) from saboteur_participants sp where sp.saboteur_game_id = g.id),
      'created_at', g.created_at
    ) order by g.created_at desc), '[]'::json)
    from saboteur_games g
    where g.owner_id = v_uid and g.status <> 'archived'
  );
end $$;

-- Knytt et spill du allerede har vertsnøkkelen til, til kontoen din.
create or replace function owner_claim_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;

  v_game := _saboteur_host(p_host_token);

  if v_game.owner_id is not null and v_game.owner_id <> v_uid then
    raise exception 'Spillet tilhører allerede en annen konto';
  end if;

  update saboteur_games set owner_id = v_uid, updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'claimed_by_account', '{}'::jsonb);
  return json_build_object('ok', true, 'saboteur_game_id', v_game.id);
end $$;

grant execute on function owner_list_saboteur_games() to authenticated;
grant execute on function owner_claim_saboteur_game(uuid) to authenticated;

-- ==========================================================================
-- ▼ 00013_saboteur_pins_phases.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00014_unique_player_names.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00014 — Unike gjestenavn per festkode (mordmysteriet)
--
-- Samme begrunnelse som for Skjult agenda: to gjester med samme navn gjør
-- vertens spillerliste umulig å lese — man vet ikke hvem man deler ut hvilken
-- rolle til.
--
-- Bevisst forsiktig her, i motsetning til i Skjult agenda: dette er en tabell
-- med ekte fester i, som kan ha duplikater fra før. Derfor sjekkes navnet i
-- join_game (som er den eneste veien inn i players), og det legges IKKE på en
-- unik indeks — en indeks ville feilet på eksisterende data og blokkert hele
-- migrasjonen. Eksisterende fester med duplikatnavn fortsetter altså å virke;
-- det er bare nye innmeldinger som må ha unikt navn.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

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

  if exists (
    select 1 from players
    where game_id = v_game.id and lower(display_name) = lower(v_name)
  ) then
    raise exception 'Navnet «%» er allerede i bruk på denne festen — velg et annet', v_name;
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

grant execute on function join_game(text, text) to anon, authenticated;

-- ==========================================================================
-- ▼ 00015_announcement_drafts.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00016_saboteur_intro_library.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00017_hint_trigger.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00018_delete_objectives_tasks.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00018 — Slett sabotørmål og oppgaver
--
-- Verten kunne opprette og endre mål/oppgaver, men aldri fjerne dem. Et
-- feilplassert mål ble dermed liggende ut kvelden.
--
-- To ting er verdt å vite om sletting:
--
-- 1) POENG FØLGER MED. Slettes et GODKJENT mål, fjernes også poengene det ga
--    (saboteur_points_ledger har ingen fremmednøkkel til målet, så det må
--    gjøres eksplisitt). Alternativet — å la poeng bli liggende for et mål
--    ingen lenger kan se — ville gjort poengtavla umulig å forklare.
--
-- 2) HINT-KOBLINGER OVERLEVER. Sletter du et mål som utløser et hint, settes
--    koblingen til null (fremmednøkkelen er «on delete set null» fra 00017),
--    og hintet blir et vanlig hint i stedet for å forsvinne. Allerede utdelte
--    hint tas aldri tilbake — deltakerne har jo lest dem.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create or replace function host_delete_objective(p_host_token uuid, p_objective_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game    saboteur_games;
  v_obj     saboteur_objectives;
  v_points  int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_obj from saboteur_objectives
  where id = p_objective_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent mål';
  end if;

  -- Fjern poeng målet eventuelt har gitt, så poengtavla forblir forklarlig.
  delete from saboteur_points_ledger
  where source_type = 'objective' and source_id = v_obj.id;
  get diagnostics v_points = row_count;

  -- Hint som ventet på dette målet mister utløseren sin (on delete set null)
  -- og oppfører seg deretter som et vanlig hint.
  delete from saboteur_objectives where id = v_obj.id;

  perform _saboteur_audit(v_game.id, 'objective_deleted',
    jsonb_build_object('objective_id', v_obj.id, 'title', v_obj.title,
                       'points_reverted', v_points > 0));
  return json_build_object('ok', true, 'points_reverted', v_points > 0);
end $$;

create or replace function host_delete_task(p_host_token uuid, p_task_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_task saboteur_tasks;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_task from saboteur_tasks where id = p_task_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent oppgave';
  end if;

  -- saboteur_hint_releases har «on delete cascade» mot oppgaven, så et hint
  -- som allerede er delt ut forsvinner fra spillerens kort sammen med
  -- oppgaven. Det er med vilje: sletter du oppgaven, fjernes hele sporet.
  delete from saboteur_tasks where id = v_task.id;

  perform _saboteur_audit(v_game.id, 'task_deleted',
    jsonb_build_object('task_id', v_task.id, 'title', v_task.title));
  return json_build_object('ok', true);
end $$;

grant execute on function host_delete_objective(uuid, uuid) to anon, authenticated;
grant execute on function host_delete_task(uuid, uuid) to anon, authenticated;

-- ==========================================================================
-- ▼ 00019_task_and_hint_libraries.sql
-- ==========================================================================

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

-- ==========================================================================
-- ▼ 00020_migration_tracking.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00020 — Hold styr på hvilke migrasjoner som er kjørt
--
-- Problemet dette løser: prosjektet har hatt 19 migrasjonsfiler og INGEN måte
-- å vite hvilke som faktisk er kjørt i en gitt database. «Kjørte jeg 00015?»
-- har bare kunnet besvares ved å prøve seg fram — og en glemt migrasjon ser
-- ut som en ødelagt funksjon, ikke som en manglende oppdatering. Det har
-- kostet flere feilsøkingsrunder.
--
-- Herfra: hver migrasjon avslutter med å registrere seg selv, og
-- `select * from schema_migrations order by version;` svarer på spørsmålet.
--
-- Denne fila registrerer også ALLE tidligere migrasjoner (00001–00019). Det
-- er en bevisst antakelse: kjører du denne, har du en database som allerede
-- er oppdatert. Stemmer ikke det, kjør supabase-schema.sql først — den er
-- komplett og idempotent — og deretter denne.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create table if not exists schema_migrations (
  version     text primary key,          -- filnavnet uten .sql, f.eks. '00015_announcement_drafts'
  applied_at  timestamptz not null default now(),
  note        text not null default ''
);

alter table schema_migrations enable row level security;
revoke all on schema_migrations from anon, authenticated;

-- Registrer en migrasjon. Kalles på slutten av hver migrasjonsfil.
create or replace function record_migration(p_version text, p_note text default '')
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into schema_migrations (version, note)
  values (p_version, coalesce(p_note, ''))
  on conflict (version) do nothing;   -- kjørt før: ikke flytt tidspunktet
end $$;

revoke execute on function record_migration(text, text) from public, anon, authenticated;

-- Hvilke migrasjoner mangler? Sammenlign lista under med filene i
-- supabase/migrations/. Kjør:
--     select * from missing_migrations();
-- Tom liste = databasen er à jour.
create or replace function missing_migrations()
returns table (version text, status text)
language plpgsql security definer set search_path = public
as $$
declare
  -- Kjent historikk per 00020. Nye migrasjoner MÅ legges til her i tillegg
  -- til å kalle record_migration(), ellers vet ikke denne funksjonen om dem.
  v_known text[] := array[
    '00001_init',
    '00002_mysteries',
    '00003_auth',
    '00004_evidence',
    '00005_profile_names',
    '00006_two_new_mysteries',
    '00007_runbooks',
    '00008_remove_evidence',
    '00009_saboteur_game',
    '00010_saboteur_discovery',
    '00011_saboteur_standalone',
    '00012_saboteur_account',
    '00013_saboteur_pins_phases',
    '00014_unique_player_names',
    '00015_announcement_drafts',
    '00016_saboteur_intro_library',
    '00017_hint_trigger',
    '00018_delete_objectives_tasks',
    '00019_task_and_hint_libraries',
    '00020_migration_tracking',
    '00021_everyone_votes'
  ];
  v_version text;
begin
  foreach v_version in array v_known loop
    if not exists (select 1 from schema_migrations sm where sm.version = v_version) then
      version := v_version;
      status  := 'IKKE KJØRT — kjør supabase/migrations/' || v_version || '.sql';
      return next;
    end if;
  end loop;
end $$;

grant execute on function missing_migrations() to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Registrer historikken. Se hovedkommentaren over for antakelsen som gjøres.
-- ----------------------------------------------------------------------------

do $$
declare
  v_version text;
  v_all text[] := array[
    '00001_init', '00002_mysteries', '00003_auth', '00004_evidence',
    '00005_profile_names', '00006_two_new_mysteries', '00007_runbooks',
    '00008_remove_evidence', '00009_saboteur_game', '00010_saboteur_discovery',
    '00011_saboteur_standalone', '00012_saboteur_account',
    '00013_saboteur_pins_phases', '00014_unique_player_names',
    '00015_announcement_drafts', '00016_saboteur_intro_library',
    '00017_hint_trigger', '00018_delete_objectives_tasks',
    '00019_task_and_hint_libraries'
  ];
begin
  foreach v_version in array v_all loop
    perform record_migration(v_version, 'registrert i etterkant av 00020');
  end loop;
end $$;

select record_migration('00020_migration_tracking', 'innfører migrasjonssporing');

-- ==========================================================================
-- ▼ 00021_everyone_votes.sql
-- ==========================================================================

-- ============================================================================
-- MIGRASJON 00021 — Alle deltakere kan stemme, ikke bare de lojale
--
-- Før kunne kun Lojale stemme. Det avslørte rollene: en sabotør som ikke fikk
-- opp stemmeskjemaet visste at de andre kunne se at hen ikke stemte, og en
-- lojal kunne slutte seg til hvem som IKKE hadde stemt. I skjult-identitet-
-- spill stemmer alle — sabotørene stemmer også, og lyver mens de gjør det.
--
-- Endringen er å fjerne rollekravet tre steder. Alt annet står:
--   • fortsatt én stemme per deltaker per runde (unik indeks i databasen)
--   • fortsatt bare mens runden er åpen
--   • fortsatt hemmelig til verten både lukker OG avslører runden
--   • inaktive deltakere kan fortsatt ikke stemme
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

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

  -- Ingen rollesjekk: alle aktive deltakere stemmer, uansett rolle.
  return json_build_object(
    'can_vote', v_round.id is not null and v_part.active and not v_voted,
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

  if v_round.id is null or not v_part.active then
    return '[]'::json;
  end if;

  -- Alle aktive deltakere kan stemmes på, inkludert en selv. Å stemme på seg
  -- selv er et fullt legitimt trekk for en sabotør som vil virke uskyldig.
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

  if not v_part.active then
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

select record_migration('00021_everyone_votes', 'alle deltakere kan stemme, ikke bare lojale');
