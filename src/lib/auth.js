// Centralized host authentication (Supabase Auth). Every auth action goes
// through this module so the rules live in one place. Supabase handles
// passwords, hashing, sessions, confirmation and recovery tokens — we never
// touch or store any of those ourselves.
//
// Redirect targets are always built from window.location.origin, so a link
// can only ever return the user to THIS app's own origin — never an arbitrary
// external URL. The matching URLs must be added to Supabase's redirect
// allowlist (see README).
import { supabase } from './supabase.js'

export const PASSWORD_MIN = 8

// Where confirmation and recovery emails send the user back to.
const authRedirect = () => `${window.location.origin}/konto.html`

export function validEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email).trim())
}

export async function getSession() {
  const { data } = await supabase.auth.getSession()
  return data.session
}

// Subscribe to sign-in / sign-out / password-recovery events. Returns an
// unsubscribe function.
export function onAuthChange(callback) {
  const { data } = supabase.auth.onAuthStateChange((event, session) => callback(event, session))
  return () => data.subscription.unsubscribe()
}

export function register({ email, password, displayName }) {
  return supabase.auth.signUp({
    email: email.trim(),
    password,
    options: {
      data: { display_name: (displayName || '').trim() },
      emailRedirectTo: authRedirect(),
    },
  })
}

export function login({ email, password }) {
  return supabase.auth.signInWithPassword({ email: email.trim(), password })
}

export function logout() {
  return supabase.auth.signOut()
}

export function requestPasswordReset(email) {
  return supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: authRedirect() })
}

export function setNewPassword(password) {
  return supabase.auth.updateUser({ password })
}

// Guard for protected pages: if there's no session, bounce to the login page
// with a ?next= so the user returns here after signing in.
export async function requireAuth(nextPath) {
  const session = await getSession()
  if (!session) {
    location.replace(`/konto.html?next=${encodeURIComponent(nextPath)}`)
    return null
  }
  return session
}

// A safe internal path to return to after login. Never returns an external
// URL — only a same-site path, defaulting to the host control page.
export function safeNext(raw) {
  if (!raw) return '/host.html'
  // Must be a root-relative path (starts with a single "/"), not "//host" or
  // "https://evil".
  if (/^\/(?!\/)/.test(raw)) return raw
  return '/host.html'
}
