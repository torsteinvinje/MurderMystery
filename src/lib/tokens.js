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

// The studio keeps a LIST of owned mysteries (author keys), since one person
// can write several. Each entry: { mystery_id, owner_token }.
const STUDIO_KEY = 'mm_studio'

export function loadStudioList() {
  const list = load(STUDIO_KEY)
  return Array.isArray(list) ? list : []
}

export function saveStudioList(list) {
  localStorage.setItem(STUDIO_KEY, JSON.stringify(list))
}

// Skjult agenda is a separate, standalone game with its own identities —
// deliberately its own storage keys, so hosting/joining a Skjult agenda game
// never interferes with an ongoing murder mystery on the same phone (and
// leaving one never logs you out of the other).
const SAB_HOST_KEY = 'mm_saboteur_host'
const SAB_PLAYER_KEY = 'mm_saboteur_player'

export const saveSaboteurHost = (data) => localStorage.setItem(SAB_HOST_KEY, JSON.stringify(data))
export const loadSaboteurHost = () => load(SAB_HOST_KEY)
export const clearSaboteurHost = () => localStorage.removeItem(SAB_HOST_KEY)

export const saveSaboteurPlayer = (data) => localStorage.setItem(SAB_PLAYER_KEY, JSON.stringify(data))
export const loadSaboteurPlayer = () => load(SAB_PLAYER_KEY)
export const clearSaboteurPlayer = () => localStorage.removeItem(SAB_PLAYER_KEY)
