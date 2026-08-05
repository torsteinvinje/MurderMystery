# AGENTS.md

The project rules live in **[CLAUDE.md](CLAUDE.md)** — read that file.

This file exists because some tools look for `AGENTS.md` by convention. It is
deliberately a pointer rather than a copy: it previously held a duplicate of
CLAUDE.md that silently fell out of date — it still described one built-in
mystery when there were three, pointed at `/skjult.html` after that page was
renamed, and omitted the Skjult agenda rules entirely. Two sources of truth are
worse than one, especially when the stale one reads as authoritative.

Everything you need — what the app is, the tech stack, the deploy rules, the
security rules that must not be broken, and the data-access conventions — is in
`CLAUDE.md`.

For build, run, test and deploy instructions, see
[`docs/BUILD-AND-DEPLOY.md`](docs/BUILD-AND-DEPLOY.md).
