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
