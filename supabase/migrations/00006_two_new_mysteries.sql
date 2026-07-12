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
