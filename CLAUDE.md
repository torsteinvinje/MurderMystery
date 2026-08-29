# CLAUDE.md — MurderMystery

Standing instructions for this project. Read at the start of every session. The one-off build plan lives in the separate build prompt; this file is only the rules that must always hold.

## What this is

**MurderMystery** — a web app for hosting Norwegian murder-mystery party games. A host runs a live in-person party; the app is the digital game master. Three experiences: a **host** view (full control, sees the solution), a **player** view (each guest joins with a code, gets a role card, marks suspicion), and a **studio** view (author your own mysteries: suspects, murderer, evidence). Mysteries are templates in a catalog; each game copies its mystery's content at creation. Built-in mysteries include "Ljåmordet på grillfesten", "Giftmordet på julebordet", and "Drapet på HR-sjefen" (each has a physical staging runbook in `runbooks/`). Game content is in **Norwegian** and stays Norwegian — only code, comments, and scaffolding are in English.

The repo also contains a **separate, standalone party game** called **Skjult agenda** (hidden-identity social deduction) at `/skjult.html`. It is NOT part of the murder mystery: it has its own join code, its own host token, its own players, and its own tables — nothing about it touches `games`/`players`/`suspects`/`polaroids`/`mysteries`. Keep it that way; don't reintroduce a dependency between the two. It is OFF by default everywhere, gated both client-side (`VITE_SABOTEUR_GAME_ENABLED`) and server-side (`app_feature_flags.SABOTEUR_GAME_ENABLED` — the real boundary; every one of its RPCs checks this first). See the README's "Skjult agenda" section before touching this code.

## Tech stack (do not swap without asking)

- Vite + vanilla JavaScript (ES modules). No TypeScript unless trivial.
- Plain CSS. Aesthetic: modern and clean — system font stack, white cards on a light gray canvas, deep red accent, mobile-first.
- Supabase (Postgres + RLS + Realtime) for data, and Netlify for hosting.

## Repo & deploy workflow (strict)

- Repo: `github.com/torsteinvinje/MurderMystery`. It is the single source of truth.
- Pipeline: commit → push to `main` → Netlify site `timely-pothos-180125` auto-builds and publishes. Production only ever comes from `main`.
- **Never deploy manually** — no `netlify deploy`, no drag-and-drop, no editing files in the Netlify UI.
- Make small, logical commits with clear messages. To "verify in production," push and wait for the Netlify build, then check the live URL.
- The repo is also connected to Supabase; keep the schema in `supabase/migrations/` so DB changes are version-controlled.

## Security rules (non-negotiable)

- The murderer's identity must never reach a player's browser before the host reveals. The `is_killer` and `resolution` columns (in both the game tables and the mystery-template tables) are protected at the database level (column grants + `get_reveal` RPC that checks game status). Do not add any client code path that reads those columns directly, and never expose them through catalog/list RPCs.
- Only the public `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` may appear in client code. The Supabase **service-role key never goes in the repo or the client bundle** — if needed, it lives only in a Netlify Function's env vars.
- Never commit secrets. `.env` is gitignored; `.env.example` documents the shape without values.
- Enable/keep RLS on every table. Never ship an open database.

## Data access rules

- The Supabase schema already exists in `supabase-schema.sql` (tables, seed data, RLS, RPCs). Use those exact table and function names — do not redesign the model.
- **All writes and all sensitive reads go through the RPCs**, called as `supabase.rpc('name', { params })`. Do not write to tables directly from the client.
- Key RPCs: `create_game`, `join_game`, `get_my_player`, `host_list_players`, `host_get_suspects`, `host_set_phase`, `host_set_status`, `host_assign_suspect`, `host_auto_assign`, `host_reveal_polaroid`, `set_suspicion`, `get_my_suspicions`, `get_reveal`, and the writeback ones `host_update_suspect`, `host_upsert_polaroid`, `host_delete_polaroid`.
- Mystery catalog/authoring RPCs: `list_mysteries` (public, never leaks solutions), `create_mystery`, and the `owner_*` family (`owner_get_mystery`, `owner_update_mystery`, `owner_upsert_suspect`, `owner_set_killer`, `owner_delete_suspect`, `owner_upsert_polaroid`, `owner_delete_polaroid`, `owner_delete_mystery`) — all validated by a secret `owner_token`.
- Skjult agenda RPCs (standalone game, opt-in, all flag-gated first): entry points `create_saboteur_game`/`join_saboteur_game`; host-side `host_get_saboteur_game`, `host_set_participant_role`, `host_auto_assign_roles`, `host_set_participant_active`, `host_remove_participant`, `host_set_know_each_other`, `host_set_show_leaderboard`, `host_set_saboteur_status`, `host_upsert_objective`/`host_decide_objective_claim`, `host_upsert_task`/`host_decide_task_claim`, `host_open_voting_round`/`host_close_voting_round`/`host_reveal_voting_round`, `host_set_max_voting_rounds`, `host_award_bonus`, `host_get_saboteur_audit`, `host_end_saboteur_game`, `host_archive_saboteur_game`; player-side `get_my_saboteur_brief`, `get_my_saboteur_vote_status`, `get_saboteur_ballot_targets`, `cast_saboteur_ballot`, `claim_saboteur_objective`/`claim_saboteur_task`. Note these take **no game id** — the host/player token identifies the game, which is what removes cross-game tampering. Same token-validated, per-viewer-payload pattern as everything else — see `supabase/migrations/00011_saboteur_standalone.sql` for the full security model.
- Editable content must persist to Supabase, never live only in browser state. Every host/author edit goes through a writeback RPC and (via Realtime, for games) reaches players' screens.
- Host identity = secret `host_token` (localStorage). Player identity = secret `player_token` (localStorage). Mystery author identity = secret `owner_token` (localStorage list). RPCs validate these; the client just passes them.

## Conventions

- Suggested layout: `/src`, `/src/lib` (supabase client), `/src/views` (host + player + studio + account + saboteur), `/src/styles`, `/supabase/migrations`, `/netlify/functions`.
- One Supabase client module reads env vars; import it everywhere else.
- Prefer clear, commented code over cleverness — the maintainer is learning this stack.
- Guests are on phones at a party: mobile-first, with clear loading and error states.
- No project-wide test runner/linter/formatter. Vitest (`npm test`) exists but is scoped only to the Skjult agenda feature (`src/lib/flags.test.js`, `tests/`) — don't assume it covers anything else.

## How to work with me

- Explain decisions briefly; I'm learning.
- Work in phases from the build prompt. After each phase, stop and give me exact commands to run and how to verify before continuing.
- Flag anything that could leak the murderer's identity to players immediately.
- If you think a different approach is clearly better, say so — but default to the choices above and ask before changing the stack or data model.
