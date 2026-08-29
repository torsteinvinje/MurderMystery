-- Reverserer 00024. Planlagte mål som aldri ble delt ut MÅ tas hånd om først:
-- kolonnen assigned_participant_id blir NOT NULL igjen, og da kan ingen rad stå
-- uten eier. Slett dem, eller del dem ut manuelt, før du kjører dette:
--   delete from saboteur_objectives where assigned_participant_id is null;
--
-- Kjør 00023 på nytt etterpå for de gamle definisjonene av
-- host_open_voting_round og host_get_saboteur_game, og 00016 for
-- host_upsert_objective / host_add_objective_from_library.
drop function if exists host_reopen_saboteur_game(uuid);
drop function if exists host_upsert_objective(uuid, uuid, uuid, text, text, int, timestamptz, smallint);
drop function if exists host_add_objective_from_library(uuid, uuid, uuid, smallint);
drop function if exists _saboteur_deal_planned(uuid);
drop function if exists _saboteur_undeal_planned(uuid);

drop index if exists saboteur_objectives_planned_idx;
alter table saboteur_objectives drop constraint if exists saboteur_objectives_target_check;
alter table saboteur_objectives drop constraint if exists saboteur_objectives_slot_check;
alter table saboteur_objectives drop column if exists planned_slot;
alter table saboteur_objectives alter column assigned_participant_id set not null;

delete from schema_migrations where version = '00024_plan_ahead';
