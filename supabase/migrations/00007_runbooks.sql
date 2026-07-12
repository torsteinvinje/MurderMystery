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
