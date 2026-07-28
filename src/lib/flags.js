// Client-side feature flags, read the same way src/lib/supabase.js reads
// VITE_SUPABASE_URL/VITE_SUPABASE_ANON_KEY: a build-time Vite env var.
//
// This is the UI-entry-point gate: with it false, no tab/card ever renders,
// no hash route resolves to 'saboteur', and no user action can reach that
// screen — verified against the built dist/ output. It does NOT guarantee
// the Skjult agenda code is physically absent from the downloaded JS bundle
// (Vite does not tree-shake across this runtime conditional), so treat it as
// "unreachable in the UI," not "secret." That's fine: it is NOT the real
// security boundary either way. Every Skjult agenda RPC independently checks
// app_feature_flags('SABOTEUR_GAME_ENABLED') in the database as its very
// first statement, so a guessed API call — or someone forcing this flag back
// on by editing the bundle — is still refused server-side. Default is false
// unless the env var is the literal string "true".
export const SABOTEUR_GAME_ENABLED = import.meta.env.VITE_SABOTEUR_GAME_ENABLED === 'true'
