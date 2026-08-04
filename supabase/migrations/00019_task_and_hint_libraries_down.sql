-- Reverserer 00019. Allerede utdelte hint beholdes som rader, men mister
-- teksten sin hvis den kom fra et tilfeldig hintkort (den sto ikke på
-- oppgaven). Vurder å notere dem ned først hvis et spill er i gang.
-- Kjør 00017 på nytt etterpå for den gamle _saboteur_release_hint, og 00016
-- for den gamle get_my_saboteur_brief.
drop function if exists host_add_task_from_library(uuid, uuid, uuid);
drop function if exists host_list_saboteur_hint_library(uuid);
drop function if exists list_saboteur_task_library();
alter table saboteur_hint_releases drop column if exists library_hint_id;
alter table saboteur_hint_releases drop column if exists hint_text;
drop table if exists saboteur_hint_library;
drop table if exists saboteur_task_library;
