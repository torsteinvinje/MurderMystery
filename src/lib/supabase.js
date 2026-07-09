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

export const supabase = createClient(url, anonKey)

// All reads and writes in this app go through database RPCs — never direct
// table access. This helper calls one and throws a readable Error on failure.
export async function rpc(name, params = {}) {
  const { data, error } = await supabase.rpc(name, params)
  if (error) throw new Error(error.message)
  return data
}
