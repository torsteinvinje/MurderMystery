import { supabase } from './supabase.js'

// Live updates without ever sending game data over the wire: the database
// inserts a harmless row in game_events whenever something changes, we get
// poked by Realtime, and re-fetch everything through the RPCs. A slow poll
// and a refresh-on-focus cover flaky party wifi where the socket drops.
export function watchGame(gameId, onPoke) {
  const channel = supabase
    .channel(`game-${gameId}`)
    .on(
      'postgres_changes',
      { event: 'INSERT', schema: 'public', table: 'game_events', filter: `game_id=eq.${gameId}` },
      () => onPoke()
    )
    .subscribe()

  const interval = setInterval(onPoke, 20000)
  const onVisible = () => { if (!document.hidden) onPoke() }
  document.addEventListener('visibilitychange', onVisible)

  // Returns a cleanup function for when the player/host leaves the game.
  return () => {
    supabase.removeChannel(channel)
    clearInterval(interval)
    document.removeEventListener('visibilitychange', onVisible)
  }
}
