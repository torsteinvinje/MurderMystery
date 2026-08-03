-- Reverserer 00012_saboteur_account.sql. Rører ingen data: dropper kun de to
-- funksjonene. saboteur_games.owner_id kom fra 00011 og beholdes.
drop function if exists owner_claim_saboteur_game(uuid);
drop function if exists owner_list_saboteur_games();
