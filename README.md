# MurderMystery

Mordmysterium til fest, som webapp. Velg (eller skriv) et mysterium, start en
fest, og la gjestene bli med fra sin egen telefon med en firetegns festkode —
med rollekort, hemmeligheter, bevis og avstemning. Verten styrer kvelden og er
den eneste som vet hvem morderen er, helt til avsløringen.

Sider:

- **`/`** — gjestene: bli med, få rolle, marker mistanke, se avsløringen
- **`/host.html`** — vertskontrollen: velg mysterium, festkode, faser, roller,
  bevis, redigering og den røde knappen
- **`/studio.html`** — verkstedet: lag egne mysterier med egne mistenkte,
  egen morder og egne bevis (alt lagres i Supabase)
- **`/konto.html`** — vertskonto: registrering, innlogging, glemt passord
- **`/skjult.html`** — «Skjult agenda»: et **eget selskapsspill** med hemmelige
  roller, helt uavhengig av mordmysteriene (valgfritt, av som standard —
  se eget avsnitt lenger nede)

Innebygde mysterier: «Ljåmordet på grillfesten», «Giftmordet på julebordet»
og «Drapet på HR-sjefen». Norsk spillinnhold, engelsk kode. Se `CLAUDE.md`
for arbeidsreglene.

**Det fysiske er halve moroa:** hvert mysterium har en kjøreplan i
[`runbooks/`](runbooks/) med rekvisittliste, regi for dødsscenen (offeret gjør
entré og dør foran gjestene!), instruks for å iscenesette og printe fysiske
polaroider, og en tidslinje der festen fortsetter mens mysteriet pågår.
Appen er vertens saksmappe og gjestenes rollekort — kjøreplanen er regien.

## Teknologi

- [Vite](https://vitejs.dev) + vanilla JavaScript (ES modules), ren CSS
- [Supabase](https://supabase.com) — Postgres med RLS, RPC-er og Realtime
- [Netlify](https://netlify.com) — hosting, bygger automatisk fra `main`

> **Skal du sette opp alt fra bunnen av — eller overta driften?**
> Se [`docs/BUILD-AND-DEPLOY.md`](docs/BUILD-AND-DEPLOY.md): en fullstendig
> teknisk gjennomgang av bygg, database, testing, deploy til Netlify,
> feilsøking, rollback og vedlikehold, med en «bygg fra null»-sjekkliste.

## Kom i gang lokalt

1. **Installer avhengigheter** (krever Node.js 20.19+):

   ```
   npm install
   ```

2. **Sett opp databasen**: åpne Supabase-prosjektet → SQL Editor → lim inn hele
   `supabase-schema.sql` og kjør den. Fila kan trygt kjøres flere ganger, og
   oppgraderer også en database som kjørte en eldre versjon.

3. **Miljøvariabler**: kopier `.env.example` til `.env` og fyll inn prosjektets
   URL og anon-nøkkel (Supabase → Project Settings → API). Bare disse to
   offentlige verdiene skal noensinne inn i klientkoden.

4. **Start utviklingsserveren**:

   ```
   npm run dev
   ```

## Datamodellen i korte trekk

- `mysteries` + `mystery_suspects` + `mystery_polaroids` er **maler**
  (katalogen). Forfattere redigerer dem i verkstedet med en hemmelig
  `owner_token`.
- `games` + `suspects` + `polaroids` + `players` + `suspicions` er **en fest**.
  Når verten starter en fest, kopieres mysteriets innhold inn i spillet —
  vertens redigeringer underveis endrer bare festens kopi.
- Klienten leser og skriver aldri tabeller direkte: RLS er på uten policies,
  og alt går via `SECURITY DEFINER`-RPC-er som validerer tokens.

## Vertskontoer (innlogging) — Supabase Auth

Verter kan lage en konto og logge inn på `/konto.html` (registrering,
innlogging, glemt/tilbakestill passord, e-postbekreftelse, kontoside). Auth
er lagt **på toppen** av token-modellen: å være vert på en fest krever ikke
konto ennå, men når en innlogget vert lager et spill eller mysterium, knyttes
det til kontoen via `owner_id` (fase A). Håndhevet eierskap (RLS) og innlogging
som krav for verkstedet kommer i fase B.

All auth-logikk ligger sentralt i `src/lib/auth.js`. Passord, sesjoner og
bekreftelses-/gjenopprettingstokens håndteres av Supabase — aldri av appen.

### Må konfigureres i Supabase (Dashboard → Authentication)

1. **Providers → Email**: slå på «Confirm email». Sett minste passordlengde til
   minst 8 og skru på «Leaked password protection» (krever betalt plan).
2. **URL Configuration → Redirect URLs**: legg til
   `http://localhost:5173/konto.html`, `https://<ditt-netlify-domene>/konto.html`
   og (valgfritt) `https://deploy-preview-*--<site>.netlify.app/konto.html`.
   Appen sender alltid brukeren tilbake til sitt eget origin/`konto.html`.
3. **Custom SMTP**: konfigurer en ekte e-postleverandør (f.eks. Resend, Postmark,
   SendGrid). Ikke bruk Supabases innebygde test-e-post i produksjon.
4. **Email Templates** (norsk): «Bekreft e-postadressen din», «Tilbakestill
   passordet ditt», og «Bekreft endring av e-postadresse».

## Skjult agenda — eget selskapsspill (AV som standard)

Et **frittstående spill**, ikke en del av mordmysteriet: noen deltakere er
hemmelige **Sabotører** med egne mål, resten er **Lojale** med egne oppgaver
og hint. Verten godkjenner oppdrag og styrer avstemningen; ingen blir kastet
ut automatisk — stemmene er bevis, verten bestemmer hva som skjer videre.

Spillet har sin **egen kode, egen vert og egne spillere**, og bor på
**`/skjult.html`**. Mordmysteriet er ikke involvert i det hele tatt: ingen
fest, ingen mystery, ingen rollekort derfra. Én side dekker alle tre roller —
den viser «start spill / bli med», vertskontroll eller spillerkortet, avhengig
av hva som ligger lagret på enheten.

**Slik spilles det:** en person åpner `/skjult.html`, trykker «Opprett spill»
og får en firetegns kode. De andre går til samme side, taster koden og navnet
sitt. Verten deler ut roller (manuelt eller tilfeldig), starter spillet, lager
mål til Sabotørene og oppgaver til de Lojale, godkjenner det folk melder inn,
åpner avstemning når det passer — og avslutter spillet, som er det eneste som
avslører rollene.

**Av som standard, overalt, på to nivåer:**

1. Klient: `VITE_SABOTEUR_GAME_ENABLED=true` i `.env` (bygges inn — se
   `.env.example`). Uten den vises ingen meny-lenke, og `/skjult.html` viser
   bare en kort «ikke slått på»-melding.
2. Database (den reelle sperren): tabellen `app_feature_flags`, rad
   `SABOTEUR_GAME_ENABLED`. Hver eneste RPC sjekker denne raden som sin aller
   første setning, uavhengig av klientflagget — et gjettet API-kall kan altså
   aldri slå på eller utnytte funksjonen.

**For å prøve det:** kjør migrasjonen `00011_saboteur_standalone.sql` (eller
hele `supabase-schema.sql`), så
`update app_feature_flags set enabled = true where key = 'SABOTEUR_GAME_ENABLED';`
i SQL Editor, og sett `VITE_SABOTEUR_GAME_ENABLED=true` (lokalt i `.env`, i
produksjon som miljøvariabel i Netlify + ny deploy, siden klientflagget bakes
inn ved bygging).

**For å skru det av igjen:** sett `enabled = false` på raden over — virker
øyeblikkelig, ingen redeploy nødvendig, og alle data beholdes. For å fjerne
det fra databasen helt: `00011_saboteur_standalone_down.sql`. Verken den eller
opp-migrasjonen rører noen gang games/players/suspects/polaroids/mysteries/profiles.

**Tester:** `npm test` (Vitest, lagt til kun for dette spillet). To testfiler
er alltid kjørbare uten database (flagg-standardverdi + statiske sikkerhets-
og «er den frittstående?»-sjekker mot selve migrasjonsfila); en tredje
(`tests/saboteur.integration.test.js`) kjører ekte RPC-kall mot en
Supabase-testdatabase og hopper over seg selv med synlig begrunnelse hvis
`SUPABASE_TEST_URL`/`SUPABASE_TEST_ANON_KEY` ikke er satt — pek den **aldri**
mot produksjonsdatabasen.

## Deploy

Produksjon kommer **kun** fra `main`: commit → push → Netlify bygger og
publiserer automatisk. Aldri deploy manuelt. Husk å sette `VITE_SUPABASE_URL`
og `VITE_SUPABASE_ANON_KEY` som miljøvariabler i Netlify-innstillingene.
`netlify.toml` setter også noen trygge sikkerhetshoder (en full CSP kommer i
auth-fase B).

## Sikkerhet (kortversjonen)

- Morderens identitet (`is_killer`) og oppklaringen (`resolution`) forlater
  aldri databasen til en spiller før verten avslører — eneste vei ut er RPC-en
  `get_reveal`, som krever spillstatus `revealed`.
- Katalogen (`list_mysteries`) røper aldri morder, hemmeligheter eller løsning;
  forfatterinnhold krever `owner_token`.
- Service-role-nøkkelen skal aldri i repoet eller klienten. `.env` er gitignorert.
