-- Reverserer 00017_hint_trigger.sql. Allerede utdelte hint beholdes
-- (saboteur_hint_releases røres ikke) — kun koblingen fjernes.
-- Kjør 00016 på nytt etterpå for de gamle definisjonene av host_upsert_task /
-- host_decide_task_claim / host_decide_objective_claim / host_get_saboteur_game.
drop function if exists host_clear_task_trigger(uuid, uuid);
drop function if exists host_upsert_task(uuid, uuid, uuid, text, text, text, text, uuid);
drop function if exists _saboteur_release_hint(uuid);
drop index if exists saboteur_tasks_trigger_idx;
alter table saboteur_tasks drop column if exists trigger_objective_id;
