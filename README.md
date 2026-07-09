# Ljåmordet på grillfesten

Et mordmysterium til grillfest, som webapp. Verten er lensmann og styrer kvelden
fra `/host.html`; gjestene blir med fra forsiden med en firetegns festkode og
får rollekort, bevis og avstemning på sin egen telefon.

Norsk spillinnhold, engelsk kode. Se `CLAUDE.md` for arbeidsreglene.

## Teknologi

- [Vite](https://vitejs.dev) + vanilla JavaScript (ES modules), ren CSS
- [Supabase](https://supabase.com) — Postgres med RLS, RPC-er og Realtime
- [Netlify](https://netlify.com) — hosting, bygger automatisk fra `main`

## Kom i gang lokalt

1. **Installer avhengigheter** (krever Node.js 18+):

   ```
   npm install
   ```

2. **Sett opp databasen**: åpne Supabase-prosjektet → SQL Editor → lim inn hele
   `supabase-schema.sql` og kjør den. Fila kan trygt kjøres flere ganger.

3. **Miljøvariabler**: kopier `.env.example` til `.env` og fyll inn prosjektets
   URL og anon-nøkkel (Supabase → Project Settings → API). Bare disse to
   offentlige verdiene skal noensinne inn i klientkoden.

4. **Start utviklingsserveren**:

   ```
   npm run dev
   ```

   Forsiden (gjest) ligger på `/`, vertsvisningen på `/host.html`.

## Deploy

Produksjon kommer **kun** fra `main`: commit → push → Netlify bygger og
publiserer automatisk. Aldri deploy manuelt. Husk å sette `VITE_SUPABASE_URL`
og `VITE_SUPABASE_ANON_KEY` som miljøvariabler i Netlify-innstillingene.

## Sikkerhet (kortversjonen)

- Morderens identitet (`suspects.is_killer`) og oppklaringen
  (`games.resolution`) forlater aldri databasen før verten avslører — eneste
  vei ut for spillere er RPC-en `get_reveal`, som krever status `revealed`.
- RLS er på for alle tabeller uten lese-/skrivepolicies; all tilgang går via
  `SECURITY DEFINER`-RPC-er som validerer `host_token`/`player_token`.
- Service-role-nøkkelen skal aldri i repoet eller klienten. `.env` er gitignorert.
