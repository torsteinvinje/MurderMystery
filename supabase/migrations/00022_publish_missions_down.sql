-- Reverserer 00022. ADVARSEL: upubliserte utkast blir synlige for spillerne
-- når published-kolonnen forsvinner, siden filteret da ikke finnes. Slett
-- eventuelle utkast FØRST:
--   delete from saboteur_objectives where not published;
--   delete from saboteur_tasks where not published;
-- Kjør 00019 på nytt etterpå for de gamle definisjonene av
-- get_my_saboteur_brief / claim_*, og 00017 for host_get_saboteur_game.
drop function if exists host_set_task_published(uuid, uuid, boolean);
drop function if exists host_set_objective_published(uuid, uuid, boolean);
alter table saboteur_objectives drop column if exists published_at;
alter table saboteur_objectives drop column if exists published;
alter table saboteur_tasks drop column if exists published_at;
alter table saboteur_tasks drop column if exists published;
delete from schema_migrations where version = '00022_publish_missions';
