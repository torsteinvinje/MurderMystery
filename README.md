# MurderMystery

Mordmysterium til fest, som webapp. Velg (eller skriv) et mysterium, start en
fest, og la gjestene bli med fra sin egen telefon med en firetegns festkode —
med rollekort, hemmeligheter, bevis og avstemning. Verten styrer kvelden og er
den eneste som vet hvem morderen er, helt til avsløringen.

Tre sider:

- **`/`** — gjestene: bli med, få rolle, marker mistanke, se avsløringen
- **`/host.html`** — vertskontrollen: velg mysterium, festkode, faser, roller,
  bevis, redigering og den røde knappen
- **`/studio.html`** — verkstedet: lag egne mysterier med egne mistenkte,
  egen morder og egne bevis (alt lagres i Supabase)

Det innebygde mysteriet er «Ljåmordet på grillfesten». Norsk spillinnhold,
engelsk kode. Se `CLAUDE.md` for arbeidsreglene.

## Teknologi

- [Vite](https://vitejs.dev) + vanilla JavaScript (ES modules), ren CSS
- [Supabase](https://supabase.com) — Postgres med RLS, RPC-er og Realtime
- [Netlify](https://netlify.com) — hosting, bygger automatisk fra `main`

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

## Deploy

Produksjon kommer **kun** fra `main`: commit → push → Netlify bygger og
publiserer automatisk. Aldri deploy manuelt. Husk å sette `VITE_SUPABASE_URL`
og `VITE_SUPABASE_ANON_KEY` som miljøvariabler i Netlify-innstillingene.

## Sikkerhet (kortversjonen)

- Morderens identitet (`is_killer`) og oppklaringen (`resolution`) forlater
  aldri databasen til en spiller før verten avslører — eneste vei ut er RPC-en
  `get_reveal`, som krever spillstatus `revealed`.
- Katalogen (`list_mysteries`) røper aldri morder, hemmeligheter eller løsning;
  forfatterinnhold krever `owner_token`.
- Service-role-nøkkelen skal aldri i repoet eller klienten. `.env` er gitignorert.
