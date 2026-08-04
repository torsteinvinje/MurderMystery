-- ============================================================================
-- MIGRASJON 00016 (NED)
--
-- Fjerner introtekst, målbibliotek og bibliotek-RPC-en. Mål som allerede er
-- lagt til i et spill beholdes — de er kopiert inn i saboteur_objectives og
-- er ikke avhengige av biblioteket.
--
-- Merk: gjenoppretter IKKE de gamle versjonene av host_upsert_objective /
-- host_upsert_task (uten tilfeldig tildeling) eller host_get_saboteur_game /
-- get_my_saboteur_brief (uten intro). Kjør 00015 på nytt etterpå hvis du
-- trenger nøyaktig de gamle definisjonene tilbake.
-- ============================================================================

drop function if exists host_add_objective_from_library(uuid, uuid, uuid);
drop function if exists list_saboteur_objective_library();
drop function if exists host_set_saboteur_intro(uuid, text);
drop function if exists _saboteur_random_participant(uuid, text);

drop table if exists saboteur_objective_library;

alter table saboteur_games drop column if exists intro;
