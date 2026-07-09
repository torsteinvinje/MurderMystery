// The host and player identities are secret tokens kept in localStorage.
// The database RPCs validate them on every call — the client just stores
// and passes them along.

const HOST_KEY = 'ljamordet_host'
const PLAYER_KEY = 'ljamordet_player'

function load(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || 'null')
  } catch {
    return null
  }
}

export const saveHost = (data) => localStorage.setItem(HOST_KEY, JSON.stringify(data))
export const loadHost = () => load(HOST_KEY)
export const clearHost = () => localStorage.removeItem(HOST_KEY)

export const savePlayer = (data) => localStorage.setItem(PLAYER_KEY, JSON.stringify(data))
export const loadPlayer = () => load(PLAYER_KEY)
export const clearPlayer = () => localStorage.removeItem(PLAYER_KEY)
