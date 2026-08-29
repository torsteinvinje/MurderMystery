-- Reverserer 00023. Poeng fra oppgaver, riktige stemmer, unnsluppet-bonus og
-- vertens bonuser BLIR STÅENDE som rader i poengregisteret — de er historiske
-- fakta fra spilte kvelder. Vil du fjerne dem også:
--   delete from saboteur_points_ledger
--    where source_type in ('task','correct_vote','undetected','adjustment');
-- Kjør 00022 på nytt etterpå for de gamle definisjonene av
-- host_get_saboteur_game / get_my_saboteur_brief / host_decide_task_claim,
-- 00021 for cast_saboteur_ballot, og 00017 for host_reveal_voting_round og
-- host_upsert_task.
drop function if exists host_award_bonus(uuid, uuid, int, text);
drop function if exists host_set_max_voting_rounds(uuid, int);
drop function if exists cast_saboteur_ballot(uuid, uuid, uuid, text);
drop function if exists host_upsert_task(uuid, uuid, uuid, text, text, text, text, uuid, int);
drop function if exists _saboteur_points_undetected(int);
drop function if exists _saboteur_points_correct_vote();
alter table saboteur_ballots drop column if exists reason;
alter table saboteur_tasks drop column if exists points;
alter table saboteur_games drop constraint if exists saboteur_games_max_rounds_check;
alter table saboteur_games drop column if exists max_voting_rounds;
delete from schema_migrations where version = '00023_scoring_loop';
