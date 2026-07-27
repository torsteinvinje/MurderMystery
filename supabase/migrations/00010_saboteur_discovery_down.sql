-- Reverses 00010_saboteur_discovery.sql. Safe at any time; drops only the
-- one function it added.
drop function if exists get_my_saboteur_game_id(uuid);
