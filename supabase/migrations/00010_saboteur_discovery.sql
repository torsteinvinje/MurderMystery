-- ============================================================================
-- MIGRASJON 00010 — Skjult agenda: spillerens oppdagelses-RPC
--
-- Gap found while wiring the player view: the HOST gets a saboteur_game_id
-- back from host_create_saboteur_game and can store it locally. A PLAYER has
-- no such id to start from — their phone only has a player_token. This RPC
-- lets a player's own device discover "is there a (non-archived) Skjult
-- agenda for my party, and what's its id" so it can then call
-- get_my_saboteur_brief with that id.
--
-- Safe to expose: it reveals only that a saboteur_game exists for the
-- caller's OWN party (same non-sensitive class of fact as "this party has a
-- murder-mystery running") — no role, no participant list, no objectives,
-- no votes. Whether the caller is actually a participant is still decided
-- entirely by get_my_saboteur_brief afterward, via the existing
-- _saboteur_participant_for_player guard.
--
-- Idempotent (safe to re-run).
-- ============================================================================

create or replace function get_my_saboteur_game_id(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_player players;
  v_sabgame saboteur_games;
begin
  if not _saboteur_enabled() then
    raise exception 'Skjult agenda er ikke slått på';
  end if;
  v_player := _player(p_player_token);

  select * into v_sabgame from saboteur_games
  where game_id = v_player.game_id and status <> 'archived'
  order by created_at desc
  limit 1;

  return json_build_object('saboteur_game_id', v_sabgame.id);
end $$;

grant execute on function get_my_saboteur_game_id(uuid) to anon, authenticated;
