-- ============================================================================
-- MURDERMYSTERY — komplett databaseskjema
--
-- Kjør hele denne fila i Supabase SQL Editor (den kan trygt kjøres på nytt,
-- og oppgraderer også en database som kjørte en eldre versjon av fila).
-- Historikken ligger som supabase/migrations/00001_init.sql + 00002_mysteries.sql.
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
--   5. Mysteriekatalogen (mysteries + mystery_suspects + mystery_polaroids)
--      er maler. Hvert spill KOPIERER innholdet ved opprettelse. Forfattere
--      redigerer med hemmelig owner_token; katalog-RPC-en list_mysteries
--      røper aldri morder, hemmeligheter eller løsning.
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

-- Mysterie-katalogen: maler som hvert spill kopierer innholdet sitt fra.
-- Forfattere identifiseres med en hemmelig owner_token (samme mønster som
-- host_token/player_token). resolution og is_killer er like beskyttet her
-- som i spillene — de nås kun via owner_*-RPC-ene.
create table if not exists mysteries (
  id          uuid primary key default gen_random_uuid(),
  owner_token uuid not null default gen_random_uuid(), -- hemmelig forfatternøkkel
  is_builtin  boolean not null default false,
  title       text not null,
  intro       text not null default '',
  resolution  text not null default '',                -- BESKYTTET
  runbook     text not null default '',                -- BESKYTTET: regi/rekvisitter, kun vert/forfatter
  created_at  timestamptz not null default now()
);
alter table mysteries add column if not exists runbook text not null default '';

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

-- Kjøreplanen (regi/rekvisitter) kopieres inn i spillet ved opprettelse.
-- BESKYTTET: inneholder løsningen, går kun ut via host_get_game.
alter table games add column if not exists runbook text not null default '';

-- Eierskap: når en INNLOGGET vert lager noe, knyttes det til kontoen (nullbart,
-- så anonyme verter fungerer som før). Se seksjon 11 (auth) nederst.
alter table games     add column if not exists owner_id uuid references auth.users (id) on delete set null;
alter table mysteries add column if not exists owner_id uuid references auth.users (id) on delete set null;
create index if not exists games_owner_idx     on games (owner_id);
create index if not exists mysteries_owner_idx on mysteries (owner_id);

-- Gamle mal-tabeller fra første versjon av skjemaet (erstattet av mysteries).
drop table if exists suspect_templates;
drop table if exists polaroid_templates;
drop table if exists story_template;

-- ----------------------------------------------------------------------------
-- 2) RLS OG RETTIGHETER
-- ----------------------------------------------------------------------------

alter table games             enable row level security;
alter table suspects          enable row level security;
alter table players           enable row level security;
alter table polaroids         enable row level security;
alter table suspicions        enable row level security;
alter table game_events       enable row level security;
alter table mysteries         enable row level security;
alter table mystery_suspects  enable row level security;
alter table mystery_polaroids enable row level security;

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
-- 3) SEED: det innebygde mysteriet «Ljåmordet på grillfesten»
-- ----------------------------------------------------------------------------

do $$
declare
  v_id uuid;
begin
  if exists (select 1 from mysteries where is_builtin) then
    return; -- allerede lagt inn
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

-- Innebygd mysterium 2: «Giftmordet på julebordet» (fysisk opplegg i runbooks/).
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

-- Innebygd mysterium 3: «Drapet på HR-sjefen» (fysisk opplegg i runbooks/).
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

-- Kjøreplaner for de innebygde mysteriene (settes bare hvis feltet er tomt,
-- så egne redigeringer aldri overskrives). Full versjon med foto-instrukser
-- ligger i runbooks/-mappen i repoet.
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

-- Den gamle parameterløse varianten må bort, ellers blir RPC-kallet tvetydig.
drop function if exists create_game();

-- Oppretter et nytt spill fra et valgt mysterium (null = det innebygde).
create or replace function create_game(p_mystery_id uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery  mysteries;
  v_game     games;
  v_code     text;
  v_chars    text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; -- uten lett forvekslbare tegn
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

  -- Finn en ledig firetegns festkode.
  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from games where code = v_code);
  end loop;

  -- Innholdet KOPIERES inn i spillet: verten kan redigere fritt underveis
  -- uten å endre mysteriet, og mysteriet kan slettes uten å knekke fester.
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
    'resolution', v_game.resolution, 'runbook', coalesce(v_game.runbook, ''),
    'created_at', v_game.created_at
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

grant execute on function create_game(uuid) to anon, authenticated;
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

-- ----------------------------------------------------------------------------
-- 10) RPC: MYSTERIEKATALOG OG FORFATTERVERKSTED
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

-- Gammel signatur (uten p_runbook) må bort, ellers blir RPC-kallet tvetydig.
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

grant execute on function list_mysteries() to anon, authenticated;
grant execute on function create_mystery(text, uuid) to anon, authenticated;
grant execute on function owner_get_mystery(uuid) to anon, authenticated;
grant execute on function owner_update_mystery(uuid, text, text, text, text) to anon, authenticated;
grant execute on function owner_upsert_suspect(uuid, uuid, text, text, text, text, text, int) to anon, authenticated;
grant execute on function owner_set_killer(uuid, uuid) to anon, authenticated;
grant execute on function owner_delete_suspect(uuid, uuid) to anon, authenticated;
grant execute on function owner_upsert_polaroid(uuid, uuid, text, text, text, int) to anon, authenticated;
grant execute on function owner_delete_polaroid(uuid, uuid) to anon, authenticated;
grant execute on function owner_delete_mystery(uuid) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 11) AUTENTISERING: vertskontoer (Supabase Auth, «lag på toppen»)
--     Se supabase/migrations/00003_auth.sql. Autentisering (hvem du er) —
--     autorisasjon (hvem som får hva) håndheves i en senere migrasjon.
-- ----------------------------------------------------------------------------

-- Profil: offentlig-trygg utvidelse av auth.users. Aldri passord/tokens her.
create table if not exists profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  first_name   text not null default '',
  last_name    text not null default '',
  display_name text not null default '',
  created_at   timestamptz not null default now()
);
alter table profiles add column if not exists first_name text not null default '';
alter table profiles add column if not exists last_name  text not null default '';

alter table profiles enable row level security;

drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Opprett profil automatisk ved registrering (fornavn + etternavn -> display_name).
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
    coalesce(nullif(trim(v_first || ' ' || v_last), ''), new.raw_user_meta_data ->> 'display_name', '')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Innlogget vert henter sin egen profil (til kontosiden + menyen).
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

-- La verten oppdatere navnet sitt.
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

-- ----------------------------------------------------------------------------
-- 12) BEVIS (Evidence) — vertens private saksmappe per fest
--     Se supabase/migrations/00004_evidence.sql. Atskilt fra polaroidene og
--     vises aldri til gjestene. Kun vert via host_token.
-- ----------------------------------------------------------------------------

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
revoke all on evidence from anon, authenticated;

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
