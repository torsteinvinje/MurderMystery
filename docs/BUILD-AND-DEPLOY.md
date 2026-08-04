# Build, run, test and deploy — complete guide

A step-by-step guide for someone who did not build this site but needs to
reproduce, run and maintain it.

Everything here is taken from the repository itself: `package.json`,
`vite.config.js`, `netlify.toml`, `supabase-schema.sql`, `supabase/migrations/`
and `.env.example`. Where a fact could not be verified from the repo, it is
marked **Needs confirmation** with exactly what is missing.

> **Conventions in this guide**
> Each major step states **what** to do, **why** it is needed, **how to verify**
> it worked, and **what to do if it fails**.

---

## 1. Overview

### What the website does

**MurderMystery** is a web app for hosting Norwegian murder-mystery parties.
A host runs a real, in-person party; the app acts as the digital game master.

It contains **two independent games**:

| Game | Where | What it is |
| --- | --- | --- |
| **Murder mystery** | `/`, `/host.html`, `/studio.html` | The host starts a party from a mystery in the catalog and gets a 4-character code. Guests join on their phones, receive a private role card (public info, a secret, an alibi), mark suspicion, see evidence photos as the host reveals them, and finally see the murderer. |
| **Skjult agenda** | `/skjult-agenda.html` | A separate hidden-identity social-deduction party game with its **own** join code, host and players. Some participants are secret *Sabotører* with objectives; the rest are *Lojale* with tasks and hints. Opt-in and **off by default**. |

Game content is in **Norwegian**; code and comments are in English.

### Main technologies

| Layer | Technology | Version (from `package.json`) |
| --- | --- | --- |
| Build tool / dev server | Vite | `^8.1.4` |
| Frontend | Vanilla JavaScript (ES modules), plain CSS | — |
| Icons | `@phosphor-icons/web` | `^2.1.2` |
| Database client | `@supabase/supabase-js` | `^2.47.0` |
| Database + auth + realtime | Supabase (PostgreSQL) | — |
| Tests | Vitest | `^4.1.10` |
| Image optimisation (dev only) | `sharp` | `^0.35.3` |
| Hosting / CI | Netlify | — |

There is **no** framework (no React/Vue/Svelte), **no** TypeScript, **no**
linter and **no** formatter in this project.

### High-level architecture

```
Browser (static files from Netlify CDN)
  index.html / host.html / studio.html / konto.html / skjult-agenda.html
  └── ES modules in src/  ──── supabase-js ────►  Supabase
                                                   ├── PostgreSQL
                                                   │   ├── RLS: ON, zero policies
                                                   │   └── SECURITY DEFINER RPCs  ← all access goes here
                                                   ├── Auth (host accounts)
                                                   └── Realtime (game_events table only)
```

Three points that define this architecture:

1. **There is no custom backend.** No Express server, and **no Netlify
   Functions** — there is no `netlify/` directory in the repo. The browser
   talks directly to Supabase using the public anon key.
2. **The client never reads or writes tables directly.** Row Level Security is
   enabled on every table with **zero policies**, so all table access is
   denied. Everything goes through `SECURITY DEFINER` PostgreSQL functions
   (RPCs) that validate a secret token and return only the fields that caller
   is entitled to see.
3. **Identity is secret tokens in `localStorage`**, not logins:
   `host_token`, `player_token`, `owner_token` (mystery author), plus separate
   Skjult agenda host/player tokens. Supabase Auth accounts exist *in addition*,
   for hosts who want their games tied to an account.

---

## 2. Prerequisites

### Accounts and access

| What | Why | Notes |
| --- | --- | --- |
| GitHub account with access to `github.com/torsteinvinje/MurderMystery` | Source of truth; Netlify deploys from it | Write access needed to push |
| Supabase account + project | Database, auth, realtime | Free tier is sufficient to run |
| Netlify account with access to the site | Hosting and deploys | See **Needs confirmation** below |

> **Needs confirmation — Netlify site identity.** `CLAUDE.md` names the Netlify
> site `timely-pothos-180125`, while the live site is served at
> `https://mordmysteriet.netlify.app`. These may be the same site after a
> rename, or two different sites. **Needed:** the correct Netlify site name/ID
> and whether a custom domain is configured.

### Software

| Tool | Version | How to check |
| --- | --- | --- |
| Node.js | **22.x** recommended — `netlify.toml` pins `NODE_VERSION = "22"` for the production build. `README.md` states 20.19+; 24.x also builds locally. | `node --version` |
| npm | Ships with Node | `npm --version` |
| Git | Any recent version | `git --version` |

Install Node.js from <https://nodejs.org> (LTS), or with a version manager:

```bash
# macOS / Linux (nvm)
nvm install 22 && nvm use 22

# Windows (winget)
winget install OpenJS.NodeJS.LTS
```

**Match the major version to `netlify.toml` (22)** if you want local builds to
behave exactly like production.

Optional:

- **Netlify CLI** — only needed for the manual-deploy escape hatch in §8.
  `npm install -g netlify-cli`
- **Supabase CLI** — *not used by this project.* Migrations are applied by
  pasting SQL into the Supabase dashboard. There is no `supabase/config.toml`
  and the project is not linked to the CLI.

**Verify:** `node --version` prints `v22.x` (or your chosen version) and
`git --version` prints a version.
**If it fails:** Node is not on your `PATH`. Reopen the terminal after
installing, or add the install directory to `PATH`.

---

## 3. Project structure

```
MurderMystery/
├── index.html               # Entry: guest / player view
├── host.html                # Entry: murder-mystery host control
├── studio.html              # Entry: mystery authoring ("Verkstedet")
├── konto.html               # Entry: host account (login/register/reset)
├── skjult-agenda.html       # Entry: Skjult agenda (separate game)
│
├── vite.config.js           # Declares the 5 entry points above
├── vitest.config.js         # Test runner config
├── netlify.toml             # Build command, publish dir, redirects, headers
├── package.json             # Scripts and dependencies
├── .env.example             # Template for local environment variables
├── supabase-schema.sql      # COMPLETE schema — the one file to run on a fresh DB
│
├── src/
│   ├── lib/
│   │   ├── supabase.js      # Creates the Supabase client; reads env vars
│   │   ├── auth.js          # All Supabase Auth calls (login, register, reset)
│   │   ├── tokens.js        # localStorage identity tokens
│   │   ├── flags.js         # VITE_SABOTEUR_GAME_ENABLED client flag
│   │   ├── realtime.js      # Subscribes to game_events (murder mystery only)
│   │   ├── nav.js           # Shared top navigation
│   │   ├── hero.js          # Hero banner component
│   │   ├── icons.js         # Phosphor icon name map
│   │   ├── phases.js        # Murder-mystery evening phases
│   │   ├── saboteur-phases.js # Skjult agenda evening phases
│   │   ├── util.js          # esc() / escMultiline() — HTML escaping
│   │   └── flags.test.js    # Unit test (runs always)
│   ├── views/               # One module per entry page
│   │   ├── player.js  host.js  studio.js  account.js  saboteur.js
│   ├── styles/main.css      # All CSS
│   └── assets/mood/*.webp   # Optimised hero images (committed)
│
├── supabase/migrations/     # Numbered migrations, 00001 → 00015
├── tests/                   # Vitest: schema assertions + integration suite
├── runbooks/                # Physical party scripts (Markdown, for humans)
├── scripts/optimize-mood-images.mjs  # Dev utility: PNG → sized WebP
└── docs/BUILD-AND-DEPLOY.md # This file
```

### Key files, and why they matter

| File | Role |
| --- | --- |
| `supabase-schema.sql` | **The complete, current schema.** Runs top-to-bottom and is idempotent. This is what you run on a new database. |
| `supabase/migrations/000NN_*.sql` | Historical, incremental changes. Use these to upgrade an *existing* database. `*_down.sql` files are rollbacks. |
| `netlify.toml` | Build command, publish directory, Node version, one redirect, four security headers. |
| `vite.config.js` | Without an entry listed here, a page will not be built. |
| `src/lib/supabase.js` | The only place env vars are read. Also implements "keep me logged in" storage. |
| `.gitignore` | Keeps `.env`, `dist/`, `node_modules/`, and the heavy source art out of git. |

**Not present in this repo** (despite being mentioned as a *suggested* layout in
`CLAUDE.md`): `netlify/functions/`. There are no serverless functions.

---

## 4. Local setup

### 4.1 Clone and install

```bash
git clone https://github.com/torsteinvinje/MurderMystery.git
cd MurderMystery
npm install
```

**Why:** installs Vite, the Supabase client, icons and the test runner.
**Verify:** `node_modules/` exists and `npm run build` (§7) completes.
**If it fails:** a `sharp` install error is usually a Node-version mismatch —
confirm `node --version` is 20.19+ and re-run `npm install`.

### 4.2 Create your environment file

```bash
cp .env.example .env      # Windows PowerShell: Copy-Item .env.example .env
```

Then open `.env` and fill in the two Supabase values from
**Supabase dashboard → Project Settings → API**.

> `.env` is gitignored. **Never commit it.** Only the two public values below
> may ever appear in client code — the Supabase **service-role key must never**
> be placed in `.env`, in the repo, or in the browser bundle.

### 4.3 Environment variables — complete list

| Variable | Purpose | Where configured | Required | Safe example |
| --- | --- | --- | --- | --- |
| `VITE_SUPABASE_URL` | Supabase project REST endpoint. Read in `src/lib/supabase.js`; a trailing `/rest/v1/` is stripped automatically. | Local `.env` **and** Netlify env vars | **Yes** — the app throws on startup without it | `https://abcdefghijklm.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | Public anon key. Safe in the browser; access is still governed by RLS + RPCs. | Local `.env` **and** Netlify env vars | **Yes** | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.<rest-of-jwt>` |
| `VITE_SABOTEUR_GAME_ENABLED` | Shows the Skjult agenda UI. Only the literal string `true` enables it. **UI gate only** — the database has its own flag (§5.5). | Local `.env` **and** Netlify env vars | No — defaults to `false` | `false` |
| `SUPABASE_TEST_URL` | Points the integration test suite at a **disposable** test project. | Shell env when running tests | No — tests skip without it | `https://testprojectref.supabase.co` |
| `SUPABASE_TEST_ANON_KEY` | Anon key for that test project. | Shell env when running tests | No | `eyJhbGciOi...` |

⚠️ **Never point `SUPABASE_TEST_URL` at production** — the integration suite
creates real games and participants.

**Verify:** `npm run dev` starts and the page renders instead of showing a
blank screen.
**If it fails:** a blank page with only the loading text almost always means the
env vars were missing *at build time*. See §10.

---

## 5. Database and SQL setup

### 5.1 Technology

**Supabase** (managed PostgreSQL) providing the database, authentication and
realtime. There is no other datastore.

### 5.2 Create the project

1. Create a project at <https://supabase.com/dashboard>.
2. Copy **Project URL** and **anon public key** from
   **Project Settings → API** into your `.env` and into Netlify (§8.3).

### 5.3 Run the schema — the correct order

**For a new/empty database (recommended):**

Run **one file**: `supabase-schema.sql`.

1. Supabase dashboard → **SQL Editor** → **New query**
2. Paste the entire contents of `supabase-schema.sql`
3. **Run**

**Why one file:** it is the complete, current schema — tables, RLS, seed
mysteries, and all RPCs — assembled in dependency order. It is idempotent
(`create table if not exists`, `create or replace function`,
`add column if not exists`), so re-running it is safe and also upgrades an
older database.

**For an existing database being brought up to date:**

Run the numbered migrations in ascending order, skipping `*_down.sql`:

```
00001_init.sql              Core: games, players, suspects, polaroids, suspicions, game_events
00002_mysteries.sql         Mystery catalog (templates) + owner_* authoring RPCs
00003_auth.sql              profiles table + host accounts (Supabase Auth)
00004_evidence.sql          (superseded — feature later removed by 00008)
00005_profile_names.sql     first_name / last_name on profiles
00006_two_new_mysteries.sql Two extra built-in mysteries
00007_runbooks.sql          runbook column (host stage directions)
00008_remove_evidence.sql   Drops the 00004 evidence feature
00009_saboteur_game.sql     (superseded by 00011)
00010_saboteur_discovery.sql(superseded by 00011)
00011_saboteur_standalone.sql  Skjult agenda rebuilt as a standalone game
00012_saboteur_account.sql  Link Skjult agenda games to a host account
00013_saboteur_pins_phases.sql Unique names, participant PINs, phases, announcements
00014_unique_player_names.sql  Unique guest names per murder-mystery party
00015_announcement_drafts.sql  Announcement drafts / edit / publish / retract
```

Notes:
- **00009 and 00010 are superseded by 00011**, which drops and rebuilds those
  objects. Running them in order is harmless.
- After any migration, if the app reports a missing function, run:
  `NOTIFY pgrst, 'reload schema';` — PostgREST caches the schema.

**Verify:** see §5.6.
**If it fails:** the SQL Editor shows the failing line. A
`relation "..." does not exist` error means an earlier migration was skipped —
run `supabase-schema.sql` instead, which is self-contained.

### 5.4 Tables and relationships

21 tables in three groups.

**Murder mystery — templates (the catalog):**

| Table | Purpose |
| --- | --- |
| `mysteries` | A mystery template. Holds `resolution` (**protected**) and `owner_token`. |
| `mystery_suspects` | Suspects belonging to a template; `is_killer` (**protected**). |
| `mystery_polaroids` | Evidence photos belonging to a template. |

**Murder mystery — a live party:**

| Table | Purpose |
| --- | --- |
| `games` | One party. Has `code`, `host_token`, `status`, `phase`, `resolution` (**protected**), optional `owner_id → auth.users`. |
| `suspects` | Roles **copied** from the template at party creation. |
| `polaroids` | Evidence **copied** from the template; `revealed` controls guest visibility. |
| `players` | Guests. Each has a secret `player_token`. |
| `suspicions` | A player's 0–3 suspicion level per suspect. |
| `game_events` | Harmless "something changed" ping stream — the **only** table exposed to Realtime. Contains no game content. |

**Skjult agenda (standalone):**

| Table | Purpose |
| --- | --- |
| `saboteur_games` | A game. Own `code`, `host_token`, `status`, `phase`. |
| `saboteur_participants` | Players. Own `player_token`, `display_name`, `pin`, `role`. |
| `saboteur_objectives` / `saboteur_tasks` | Sabotør objectives / Lojal tasks. |
| `saboteur_hint_releases` | Which hint has been released to whom. |
| `saboteur_voting_rounds` / `saboteur_ballots` | Voting; one ballot per participant per round (unique index). |
| `saboteur_points_ledger` | Append-only score events; idempotent by `(source_type, source_id)`. |
| `saboteur_announcements` | Host messages; `published` controls guest visibility. |
| `saboteur_audit_log` | Append-only host-action log. |

**Shared:**

| Table | Purpose |
| --- | --- |
| `profiles` | Public-safe extension of `auth.users` (names only — never passwords). |
| `app_feature_flags` | Server-side feature flags. Holds `SABOTEUR_GAME_ENABLED`. |

**Key copy-on-create relationship:** `mysteries → games`. When a host starts a
party, the mystery's content is **copied** into the game. Editing a mystery
afterwards never disturbs a running party, and deleting a mystery never breaks
one.

**Permissions model:** RLS is enabled on every table with **no policies**, and
table privileges are revoked from `anon`/`authenticated`. All access is through
`SECURITY DEFINER` functions (83 `create or replace function` definitions in
the canonical schema). The murderer's identity (`is_killer`) and the solution
(`resolution`) can only leave the database via `get_reveal`, which requires the
game's status to be `revealed`.

### 5.5 Enable Skjult agenda (optional)

The feature is off at **two** independent levels and needs both:

```sql
-- 1. The real gate (server-side)
update app_feature_flags set enabled = true where key = 'SABOTEUR_GAME_ENABLED';
```

```bash
# 2. The UI gate (build-time) — locally in .env, in production a Netlify env var
VITE_SABOTEUR_GAME_ENABLED=true
```

The client flag is compiled in at build time, so **production needs a redeploy**
after changing it. Turning the feature *off* via SQL takes effect immediately
and needs no redeploy.

### 5.6 Validation queries

Run these in the SQL Editor after setup:

```sql
-- 1. All 21 tables exist
select count(*) as tables from information_schema.tables
 where table_schema = 'public';

-- 2. RLS is enabled everywhere and there are no policies (expect: 0 rows)
select tablename from pg_tables
 where schemaname = 'public'
   and tablename not in (select tablename from pg_tables where rowsecurity);

-- 3. Built-in mysteries are seeded (expect 3)
select title, is_builtin from mysteries order by created_at;

-- 4. The public catalog RPC works and leaks no solutions
select list_mysteries();

-- 5. Skjult agenda flag state
select * from app_feature_flags;

-- 6. Realtime is listening to game_events only
select tablename from pg_publication_tables where pubname = 'supabase_realtime';
```

**Expected:** query 3 returns *Ljåmordet på grillfesten*, *Giftmordet på
julebordet*, *Drapet på HR-sjefen*; query 4 returns JSON with titles and counts
but **no** `resolution` or `is_killer`; query 6 returns `game_events`.

### 5.7 Supabase Auth configuration (host accounts)

Required for `/konto.html` (register / login / password reset) to work
end-to-end. **Authentication → …** in the dashboard:

1. **Providers → Email:** enable *Confirm email*; minimum password length ≥ 8;
   enable *Leaked password protection* (paid plans).
2. **URL Configuration → Site URL:** your production URL
   (e.g. `https://mordmysteriet.netlify.app`).
3. **URL Configuration → Redirect URLs:** add
   `http://localhost:5173/konto.html`,
   `https://<your-netlify-domain>/konto.html`, and optionally
   `https://deploy-preview-*--<site>.netlify.app/konto.html`.
4. **Custom SMTP:** configure a real provider for production email.

> **Needs confirmation — SMTP.** No SMTP provider is recorded anywhere in the
> repo. **Needed:** which provider is used in production (e.g. Resend,
> Postmark, SendGrid) and who holds those credentials.

**Why step 2/3 matter:** if the Site URL is wrong, confirmation emails send
users to the wrong host (a known past failure: links pointed at
`localhost:3000`).

---

## 6. Run the application locally

```bash
npm run dev
```

Vite prints a local URL, by default **<http://localhost:5173>**.

| Page | URL |
| --- | --- |
| Guest / player | `http://localhost:5173/` |
| Murder-mystery host | `http://localhost:5173/host.html` |
| Mystery authoring | `http://localhost:5173/studio.html` |
| Host account | `http://localhost:5173/konto.html` |
| Skjult agenda | `http://localhost:5173/skjult-agenda.html` |

### Test the main flows

**A. Murder mystery (needs two browser windows — use a private/incognito
window as the guest, so the two `localStorage` identities don't collide):**

1. Open `/host.html` → pick a mystery → **Start fest**.
   *Expected:* a 4-character code appears.
2. In the guest window open `/` → enter the code and a name → **Bli med**.
   *Expected:* the guest appears in the host's **Spillere** tab.
3. Host: **Spillere** → *Del ut ledige roller automatisk*.
   *Expected:* the guest's screen shows a role card with a secret and an alibi.
4. Host: **Bevis** → reveal one item.
   *Expected:* it appears on the guest's screen within a few seconds (Realtime).
5. Host: **Avsløring** → the red button (two taps).
   *Expected:* the guest sees the murderer and the resolution — and **not
   before** this point.

**B. Skjult agenda** (only if enabled per §5.5):

1. `/skjult-agenda.html` → **Opprett spill** → note the code.
2. Private window → same page → **Bli med** with the code and a name.
   *Expected:* a personal 4-digit PIN is shown to the guest and appears next to
   their name in the host's participant list.
3. Host: assign roles (or *Del ut roller tilfeldig*) → **Start spillet**.
4. Host: write a *beskjed*, tick *Publiser med én gang* → **Lagre**.
   *Expected:* it appears on the guest's screen.

**If a flow fails:** check the browser console (F12) for the RPC error; most
failures are a missing migration and now name the file to run.

---

## 7. Build and test

### Production build

```bash
npm run build
```

**What success looks like** — Vite lists the five HTML entry points and the
hashed assets, ending with `✓ built in <time>`:

```
dist/index.html                  ...
dist/host.html                   ...
dist/studio.html                 ...
dist/konto.html                  ...
dist/skjult-agenda.html          ...
dist/assets/...js  .css  .webp  Phosphor-*.woff2
✓ built in 3.09s
```

Preview the built output exactly as it will be served:

```bash
npm run preview
```

### Tests

```bash
npm test          # vitest run
```

**Expected output:** `Test Files 2 passed | 1 skipped`, and
`Tests 38 passed | 25 skipped`.

The skipping is intentional and honest, not a failure:

| File | Runs | Covers |
| --- | --- | --- |
| `src/lib/flags.test.js` | Always | The client flag defaults to `false`; only `"true"` enables it. |
| `tests/saboteur-schema.test.js` | Always | Static assertions against the real migration SQL: RLS on with no policies, every RPC flag-gated, uniqueness constraints, drafts never sent to players, down-migrations match up-migrations. |
| `tests/saboteur.integration.test.js` | Only with `SUPABASE_TEST_URL` + `SUPABASE_TEST_ANON_KEY` | Real RPC round-trips against a disposable test project. |

To run the integration suite:

```bash
SUPABASE_TEST_URL="https://<test-ref>.supabase.co" \
SUPABASE_TEST_ANON_KEY="<test-anon-key>" \
npm test
```

⚠️ Use a **throwaway** Supabase project. Never production.

### What does **not** exist

There is **no lint, no formatter, no type-checking, and no database-migration
validation command** in this project. `npm test` is the only automated check,
and it covers the Skjult agenda feature only — not the murder-mystery flows.

### Common build failures

| Symptom | Cause | Fix |
| --- | --- | --- |
| `Mangler VITE_SUPABASE_URL eller VITE_SUPABASE_ANON_KEY i miljøet` | Env vars missing at build time | Create `.env` (§4.2); in production set them in Netlify and **redeploy** |
| A page 404s in production but works in dev | Its entry is missing from `vite.config.js` | Add it to `rollupOptions.input` and rebuild |
| `sharp` fails to install | Node version mismatch | Use Node 20.19+/22; `rm -rf node_modules && npm install` |

---

## 8. Netlify deployment

### 8.1 Connect the repository

1. Netlify → **Add new site → Import an existing project → GitHub**
2. Select `torsteinvinje/MurderMystery`
3. Branch to deploy: **`main`**

Build settings are read automatically from `netlify.toml` — do not retype them:

| Setting | Value | Source |
| --- | --- | --- |
| Build command | `npm run build` | `netlify.toml` → `[build] command` |
| Publish directory | `dist` | `netlify.toml` → `[build] publish` |
| Node version | `22` | `netlify.toml` → `[build.environment] NODE_VERSION` |

### 8.2 The deployment rule

**Production only ever comes from `main`.** Commit → push to `main` → Netlify
builds and publishes automatically. Per `CLAUDE.md`, **do not deploy manually**
(no drag-and-drop, no editing files in the Netlify UI) — a manual deploy makes
the live site diverge from the repository.

### 8.3 Netlify environment variables

**Site configuration → Environment variables:**

| Variable | Value | Required |
| --- | --- | --- |
| `VITE_SUPABASE_URL` | Your Supabase project URL | **Yes** |
| `VITE_SUPABASE_ANON_KEY` | Your Supabase anon key | **Yes** |
| `VITE_SABOTEUR_GAME_ENABLED` | `true` to expose Skjult agenda | No |

These are **build-time** variables baked into the bundle. **Adding or changing
one requires a new deploy** — Netlify does not rebuild automatically when you
edit an env var. Use **Deploys → Trigger deploy → Deploy site**.

Never add the Supabase **service-role key** here: everything in a `VITE_`
variable ends up in the public browser bundle.

### 8.4 Netlify features in use

**Redirects** (`netlify.toml`) — one:

```toml
[[redirects]]
  from = "/skjult.html"
  to = "/skjult-agenda.html"
  status = 301
  force = true
```

Keeps previously shared links and printed QR codes working after the page was
renamed.

**Headers** (`netlify.toml`) — applied to `/*`:

| Header | Value |
| --- | --- |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Permissions-Policy` | `geolocation=(), camera=(), microphone=()` |

A full Content-Security-Policy is **not** configured; the comment in
`netlify.toml` notes it was deferred because it must be tested against
Supabase's REST and Realtime (`wss`) connections.

**Not used:** serverless functions, scheduled functions, Netlify Forms,
Edge Functions, and SPA catch-all rewrites. This is a genuine multi-page site —
each page is a real `.html` file, so deep links and refreshes work without a
fallback rule.

### 8.5 Preview vs production deploys

| | Trigger | URL |
| --- | --- | --- |
| **Production** | Push/merge to `main` | The site's primary domain |
| **Deploy Preview** | Open a pull request | `https://deploy-preview-<PR>--<site>.netlify.app` |
| **Branch deploy** | Push to a non-`main` branch (if enabled) | `https://<branch>--<site>.netlify.app` |

Deploy Previews use the same environment variables. If you test login on a
preview URL, add that URL pattern to Supabase's redirect allowlist (§5.7).

### 8.6 Git-based deploy (normal path)

```bash
git checkout -b my-change
# ...edit...
npm test && npm run build      # verify before pushing
git add -A
git commit -m "Describe the change"
git push -u origin my-change
# open a PR, review the Deploy Preview, then merge to main
```

**Verify:** Netlify **Deploys** shows a green *Published* entry for `main`.

### 8.7 Manual deploy (escape hatch only)

Discouraged by the project's own rules; use only if Git-based deploys are
broken and the site must be restored.

```bash
npm run build
netlify deploy --dir=dist --prod
```

Afterwards, push the same code to `main` so the repo and the live site match.

---

## 9. Post-deployment checks

Work through this after every production deploy.

**Site and pages**

- [ ] `/` loads and shows the join form (not a blank page)
- [ ] `/host.html` lists mysteries with "Klart til å spilles" badges
- [ ] `/studio.html` loads
- [ ] `/konto.html` loads
- [ ] `/skjult-agenda.html` loads (or shows "ikke slått på" when disabled)
- [ ] `/skjult.html` redirects to `/skjult-agenda.html` (301)

**Database connection**

- [ ] Creating a party on `/host.html` returns a 4-character code
      *(proves the anon key, RPCs and RLS all work)*
- [ ] Joining from a second device/incognito window succeeds
- [ ] The new guest appears on the host screen within ~20 seconds (Realtime)

**Authentication** (if in use)

- [ ] Register with a real address → confirmation email arrives
- [ ] The confirmation link returns to **your production domain**, not localhost
- [ ] Login works; refreshing the page keeps you logged in
- [ ] Password reset email arrives and sets a new password

**Secrecy — the most important check**

- [ ] Before the reveal, a guest's browser has no way to see the murderer:
      DevTools → Network → inspect the responses to `get_my_player`,
      `get_public_suspects`, `get_public_polaroids` → **no** `is_killer` or
      `resolution` fields
- [ ] `get_reveal` fails before the host presses the red button
- [ ] After the reveal, the guest sees the murderer and resolution

**Skjult agenda** (if enabled)

- [ ] Create a game, join from another device, PIN shown to guest and host
- [ ] An unpublished *beskjed* is **not** visible on the guest's screen
- [ ] Publishing it makes it appear
- [ ] Roles stay hidden until the host ends the game

**Where to check logs**

| Where | What you see |
| --- | --- |
| Netlify → **Deploys** → a deploy → *Deploy log* | Build output, failed builds, missing env vars |
| Browser **DevTools → Console / Network** | Client-side and RPC errors (this is where most runtime problems surface) |
| Supabase → **Logs → API / Postgres** | RPC calls, SQL errors, RLS denials |
| Supabase → **Authentication → Users / Logs** | Signup, confirmation, login problems |

---

## 10. Troubleshooting and rollback

### Errors specific to this project

| Symptom | Cause | Fix |
| --- | --- | --- |
| Blank page showing only "Blar i saksmappa …" / "Laster …" | Env vars missing **at build time** — the app throws on startup | Set `VITE_SUPABASE_URL` + `VITE_SUPABASE_ANON_KEY` in Netlify, then **Trigger deploy**. Locally: create `.env` and restart `npm run dev` |
| `Could not find the function public.<name> in the schema cache` | A migration has not been run, or PostgREST's cache is stale | Run the migration named in the error, then `NOTIFY pgrst, 'reload schema';` and wait ~10 s |
| `Fant ingen fest med koden «XXXX»` when joining Skjult agenda | The code was entered on `/` (murder mystery) instead of `/skjult-agenda.html` | Use the Skjult agenda page. The two games have separate, identical-looking codes |
| Confirmation email links to `localhost:3000` | Supabase **Site URL** is still the default | Set Site URL + Redirect URLs (§5.7) |
| `cannot change return type of existing function` | A migration redefines a function with a new signature | `drop function <name>(<arg types>);` then re-run the migration |
| `relation "profiles" does not exist` | Migrations were run out of order | Run `supabase-schema.sql` — it is self-contained |
| `column "suspect_id" does not exist` | The database predates an early migration | Run `supabase-schema.sql` |
| Name rejected when joining | Duplicate names are blocked per party/game (00013/00014) | Choose a different name |
| Skjult agenda invisible after enabling the SQL flag | The client flag is baked in at build time | Set `VITE_SABOTEUR_GAME_ENABLED=true` in Netlify and redeploy |

### Rolling back a bad deploy

**Fastest (no rebuild) — instant rollback in Netlify:**

1. Netlify → **Deploys**
2. Find the last known-good deploy
3. **⋯ → Publish deploy**

The site immediately serves that build again. This does **not** change the
repository, so fix the code afterwards.

**Then correct the repository:**

```bash
git revert <bad-commit-sha>     # safe: creates a new commit, keeps history
git push origin main
```

Avoid `git reset --hard` / `--force` on `main`.

**Rolling back the database:**

Database changes are **not** rolled back by reverting a deploy. Skjult agenda
migrations ship `*_down.sql` files (e.g.
`00015_announcement_drafts_down.sql`). Only run one when you are certain, and
read its header first — some warn about data loss.

To disable Skjult agenda without any migration or deploy:

```sql
update app_feature_flags set enabled = false where key = 'SABOTEUR_GAME_ENABLED';
```

**Order of operations for a bad release:** roll back the Netlify deploy first
(seconds, restores service), then decide about the database. Prefer disabling a
feature over dropping data.

---

## 11. Ongoing maintenance

### Dependencies

```bash
npm outdated          # what is behind
npm update            # minor/patch upgrades
npm audit             # vulnerabilities
npm audit fix         # safe fixes
npm test && npm run build   # always verify after upgrading
```

Major upgrades (especially Vite) should go through a PR so the Deploy Preview
can be checked before merging.

### Database schema changes

1. Add a **new numbered file** in `supabase/migrations/` (never edit an applied
   one).
2. Provide a matching `*_down.sql` where a rollback is meaningful.
3. Fold the same change into `supabase-schema.sql` so a fresh install stays
   correct. *(That file executes top-to-bottom; later definitions of the same
   function intentionally supersede earlier ones.)*
4. Apply it in Supabase via the SQL Editor, then `NOTIFY pgrst, 'reload schema';`

**Keep:** RLS enabled with no policies; all access through `SECURITY DEFINER`
RPCs; the feature-flag check as the **first statement** of every Skjult agenda
RPC.

### Environment variables

Changing a Netlify env var requires a **redeploy** to take effect. Keep `.env`
and Netlify in sync, and update `.env.example` (without values) when adding a
variable.

### Content

- **Mysteries** are edited in the app at `/studio.html`, not in code.
- **Built-in mysteries** are seeded by SQL (`00002`, `00006`) — changing them
  requires a migration.
- **Physical party scripts** live in `runbooks/*.md`.
- **Hero images:** put source art in `mood-src/` and run
  `node scripts/optimize-mood-images.mjs`; only the optimised
  `src/assets/mood/*.webp` are committed.

### What to back up

| What | How |
| --- | --- |
| **Supabase database** | Dashboard → Database → Backups. Verify the retention on your plan; free tier is limited. **This is the only irreplaceable asset** — code is in git, but live parties, accounts and authored mysteries are not. |
| Supabase Auth settings | Document Site URL, redirect URLs, SMTP config (no repo record today) |
| Netlify env vars | Keep a record outside Netlify |
| Repository | Already distributed via GitHub |

### Files to treat with care

| File | Why |
| --- | --- |
| `supabase-schema.sql` | The source of truth for a fresh database |
| `supabase/migrations/*` | History; never edit an already-applied migration |
| `netlify.toml` | Build, redirects and security headers |
| `vite.config.js` | Removing an entry silently removes a page |
| `src/lib/supabase.js` | The only env-var reader; also the auth session storage |
| `.gitignore` | Keeps `.env` out of git |

**Never** commit `.env`, and never put the service-role key in any `VITE_`
variable.

---

## Build-from-zero checklist

From an empty computer and a new Netlify site to a working production site.

**Local**

- [ ] Install Node.js 22 and Git → `node --version`, `git --version`
- [ ] `git clone https://github.com/torsteinvinje/MurderMystery.git`
- [ ] `cd MurderMystery && npm install`

**Database**

- [ ] Create a Supabase project
- [ ] SQL Editor → paste all of `supabase-schema.sql` → **Run**
- [ ] Run the validation queries in §5.6 (expect 3 built-in mysteries)
- [ ] Copy Project URL + anon key from Project Settings → API

**Local run**

- [ ] `cp .env.example .env` and fill in the two Supabase values
- [ ] `npm run dev` → open <http://localhost:5173>
- [ ] Create a party on `/host.html`, join from an incognito window on `/`

**Verify before deploying**

- [ ] `npm test` → 38 passed, 25 skipped
- [ ] `npm run build` → `✓ built`, five HTML files in `dist/`

**Netlify**

- [ ] Create a site from the GitHub repo, deploy branch `main`
- [ ] Confirm build command `npm run build` and publish dir `dist`
      (read from `netlify.toml`)
- [ ] Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`
- [ ] Optionally add `VITE_SABOTEUR_GAME_ENABLED=true`
- [ ] **Deploys → Trigger deploy → Deploy site**

**Supabase Auth** (if host accounts are used)

- [ ] Enable *Confirm email*; set min password length ≥ 8
- [ ] Set **Site URL** to the production URL
- [ ] Add redirect URLs for production and `localhost:5173`
- [ ] Configure custom SMTP

**Skjult agenda** (optional)

- [ ] `update app_feature_flags set enabled = true where key = 'SABOTEUR_GAME_ENABLED';`
- [ ] `VITE_SABOTEUR_GAME_ENABLED=true` in Netlify → redeploy

**Go-live checks**

- [ ] Work through the §9 checklist, especially the secrecy checks
- [ ] Run one full party end-to-end: create → join → assign roles → reveal
      evidence → reveal murderer

---

## Open items — Needs confirmation

| # | Item | What is needed |
| --- | --- | --- |
| 1 | Netlify site identity | `CLAUDE.md` says `timely-pothos-180125`; the live URL is `mordmysteriet.netlify.app`. Confirm the site name/ID, and whether a custom domain exists. |
| 2 | SMTP provider | No provider recorded in the repo. Confirm which service sends confirmation/reset email in production and who holds the credentials. |
| 3 | Supabase project reference | Deliberately not recorded here (secrets policy). Whoever maintains the site needs dashboard access. |
| 4 | Supabase plan / backup retention | Determines whether *Leaked password protection* is available and how long backups are kept. |
| 5 | Applied migration state | There is no migration-tracking table. Confirm which migrations have been applied to production, or re-run `supabase-schema.sql` (idempotent) to guarantee it is current. |
