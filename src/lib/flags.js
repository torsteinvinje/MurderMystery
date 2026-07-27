// Client-side feature flags, read the same way src/lib/supabase.js reads
// VITE_SUPABASE_URL/VITE_SUPABASE_ANON_KEY: a build-time Vite env var.
//
// This is the UI-entry-point gate only — it hides the Skjult agenda tab/card
// from the bundle. It is NOT the real security boundary: every Skjult agenda
// RPC also checks app_feature_flags('SABOTEUR_GAME_ENABLED') in the database
// as its first statement, so a guessed API call is refused server-side even
// if someone re-enabled this client flag by hand. Default is false unless
// the env var is the literal string "true".
export const SABOTEUR_GAME_ENABLED = import.meta.env.VITE_SABOTEUR_GAME_ENABLED === 'true'
