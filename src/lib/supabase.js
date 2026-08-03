import { createClient } from '@supabase/supabase-js'

// The ONLY two values that may ever appear in client code: the public project
// URL and the public anon key. Locally they come from .env; in production
// they are set as environment variables on the Netlify site.
const rawUrl = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!rawUrl || !anonKey) {
  throw new Error('Mangler VITE_SUPABASE_URL eller VITE_SUPABASE_ANON_KEY i miljøet')
}

// createClient wants the project root URL; tolerate a pasted REST endpoint.
const url = rawUrl.replace(/\/rest\/v1\/?$/, '')

// "Husk meg på denne enheten" (see src/views/account.js). Supabase keeps the
// session in whatever storage we hand it, so the choice is made here rather
// than by signing people out later:
//   remembered (default) -> localStorage: survives closing the browser
//   not remembered       -> sessionStorage: gone when the tab closes
// The preference itself lives in localStorage so it survives either way.
const REMEMBER_KEY = 'mm_remember_me'

export function setRememberMe(remember) {
  localStorage.setItem(REMEMBER_KEY, remember ? 'true' : 'false')
}

export function getRememberMe() {
  return localStorage.getItem(REMEMBER_KEY) !== 'false' // default: remember
}

// Routes each read/write to the storage the current preference implies.
// Removal always clears both, so switching modes can't strand a stale session.
const sessionStore = {
  getItem: (key) => (getRememberMe() ? localStorage : sessionStorage).getItem(key),
  setItem: (key, value) => (getRememberMe() ? localStorage : sessionStorage).setItem(key, value),
  removeItem: (key) => {
    localStorage.removeItem(key)
    sessionStorage.removeItem(key)
  },
}

export const supabase = createClient(url, anonKey, {
  auth: {
    storage: sessionStore,
    persistSession: true,
    autoRefreshToken: true, // keeps a remembered session alive instead of expiring mid-party
  },
})

// All reads and writes in this app go through database RPCs — never direct
// table access. This helper calls one and throws a readable Error on failure.
export async function rpc(name, params = {}) {
  const { data, error } = await supabase.rpc(name, params)
  if (error) throw new Error(error.message)
  return data
}
