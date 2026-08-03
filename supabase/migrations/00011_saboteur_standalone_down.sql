-- ============================================================================
-- MIGRASJON 00011 (NED) — Fjern det frittstående Skjult agenda helt
--
-- Reverserer 00011_saboteur_standalone.sql. Rører ALDRI mordmysteriet sine
-- tabeller (games/players/suspects/polaroids/mysteries/profiles) — alt som
-- droppes her ble laget av opp-migrasjonen.
--
-- Merk: for å bare skru funksjonen AV trenger du ikke denne fila i det hele
-- tatt. Kjør heller:
--   update app_feature_flags set enabled = false where key = 'SABOTEUR_GAME_ENABLED';
-- Det virker øyeblikkelig og beholder alle data. Denne fila er for å fjerne
-- funksjonen fra databasen for godt.
-- ============================================================================

drop function if exists claim_saboteur_task(uuid, uuid);
drop function if exists claim_saboteur_objective(uuid, uuid);
drop function if exists cast_saboteur_ballot(uuid, uuid, uuid);
drop function if exists get_saboteur_ballot_targets(uuid);
drop function if exists get_my_saboteur_vote_status(uuid);
drop function if exists get_my_saboteur_brief(uuid);

drop function if exists host_get_saboteur_audit(uuid);
drop function if exists host_reveal_voting_round(uuid, uuid);
drop function if exists host_close_voting_round(uuid, uuid);
drop function if exists host_open_voting_round(uuid);
drop function if exists host_decide_task_claim(uuid, uuid, boolean);
drop function if exists host_upsert_task(uuid, uuid, uuid, text, text, text, text);
drop function if exists host_decide_objective_claim(uuid, uuid, boolean);
drop function if exists host_upsert_objective(uuid, uuid, uuid, text, text, int, timestamptz);
drop function if exists host_archive_saboteur_game(uuid);
drop function if exists host_end_saboteur_game(uuid);
drop function if exists host_set_saboteur_status(uuid, text);
drop function if exists host_set_show_leaderboard(uuid, boolean);
drop function if exists host_set_know_each_other(uuid, boolean);
drop function if exists host_remove_participant(uuid, uuid);
drop function if exists host_set_participant_active(uuid, uuid, boolean);
drop function if exists host_auto_assign_roles(uuid, int);
drop function if exists host_set_participant_role(uuid, uuid, text);
drop function if exists host_get_saboteur_game(uuid);

drop function if exists join_saboteur_game(text, text);
drop function if exists create_saboteur_game(text, boolean);

drop function if exists _saboteur_apply_transition(uuid, text);
drop function if exists _saboteur_audit(uuid, text, jsonb);
drop function if exists _saboteur_me(uuid);
drop function if exists _saboteur_host(uuid);
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

-- app_feature_flags ble laget for denne funksjonen og brukes ikke av noe
-- annet ennå. Har du siden lagt inn andre flagg, fjern linja under og kjør
-- i stedet: delete from app_feature_flags where key = 'SABOTEUR_GAME_ENABLED';
drop table if exists app_feature_flags;
