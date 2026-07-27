-- ============================================================================
-- MIGRASJON 00009 (NED) — Fjern Skjult agenda helt
--
-- Reverses 00009_saboteur_game.sql completely. Safe to run at any time: it
-- NEVER touches games/players/suspects/polaroids/mysteries/profiles or any
-- of their data — every object dropped here was created fresh by the up
-- migration. Only run this if you want the feature removed from the
-- database entirely; for a normal, instant, reversible disable, just set
-- app_feature_flags.enabled = false for key 'SABOTEUR_GAME_ENABLED'
-- (no SQL file needed for that — see README).
-- ============================================================================

drop function if exists claim_saboteur_task(uuid, uuid, uuid);
drop function if exists claim_saboteur_objective(uuid, uuid, uuid);
drop function if exists cast_saboteur_ballot(uuid, uuid, uuid, uuid);
drop function if exists get_saboteur_ballot_targets(uuid, uuid);
drop function if exists get_my_saboteur_vote_status(uuid, uuid);
drop function if exists get_my_saboteur_brief(uuid, uuid);

drop function if exists host_get_saboteur_audit(uuid, uuid);
drop function if exists host_get_saboteur_game(uuid, uuid);
drop function if exists host_reveal_voting_round(uuid, uuid, uuid);
drop function if exists host_close_voting_round(uuid, uuid, uuid);
drop function if exists host_open_voting_round(uuid, uuid);
drop function if exists host_decide_task_claim(uuid, uuid, uuid, boolean);
drop function if exists host_upsert_task(uuid, uuid, uuid, uuid, text, text, text, text);
drop function if exists host_decide_objective_claim(uuid, uuid, uuid, boolean);
drop function if exists host_upsert_objective(uuid, uuid, uuid, uuid, text, text, int, timestamptz);
drop function if exists host_archive_saboteur_game(uuid, uuid);
drop function if exists host_end_saboteur_game(uuid, uuid);
drop function if exists host_set_saboteur_status(uuid, uuid, text);
drop function if exists host_set_show_leaderboard(uuid, uuid, boolean);
drop function if exists host_set_know_each_other(uuid, uuid, boolean);
drop function if exists host_set_participant_active(uuid, uuid, uuid, boolean);
drop function if exists host_set_participants(uuid, uuid, jsonb);
drop function if exists host_list_eligible_participants(uuid, uuid);
drop function if exists host_create_saboteur_game(uuid, boolean);

drop function if exists _saboteur_apply_transition(uuid, text);
drop function if exists _saboteur_audit(uuid, text, jsonb);
drop function if exists _saboteur_participant_for_player(uuid, uuid);
drop function if exists _saboteur_game_for_host(uuid, uuid);
drop function if exists _saboteur_enabled();

drop table if exists saboteur_audit_log;
drop table if exists saboteur_points_ledger;
drop table if exists saboteur_ballots;
drop table if exists saboteur_voting_rounds;
drop table if exists saboteur_hint_releases;
drop table if exists saboteur_tasks;
drop table if exists saboteur_objectives;
drop table if exists saboteur_participants;
drop table if exists saboteur_games;

-- app_feature_flags was created by the up-migration solely for this
-- feature; nothing else uses it yet, so it's dropped too for a full revert.
-- If you've since added other flags to this table, remove this last line
-- and instead run: delete from app_feature_flags where key = 'SABOTEUR_GAME_ENABLED';
drop table if exists app_feature_flags;
