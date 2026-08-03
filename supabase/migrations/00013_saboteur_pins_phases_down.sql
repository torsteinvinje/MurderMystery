-- ============================================================================
-- MIGRASJON 00013 (NED)
--
-- Fjerner PIN/unike navn, regi (phase) og beskjeder. Merk at dette IKKE
-- gjenoppretter de gamle versjonene av join_saboteur_game /
-- host_get_saboteur_game / get_my_saboteur_brief — kjør 00011 på nytt
-- etterpå hvis du trenger dem tilbake i gammel form.
--
-- Sletter beskjeder (saboteur_announcements) og alle PIN-koder. Deltakere,
-- roller, mål, oppgaver, poeng og stemmer røres ikke.
-- ============================================================================

drop function if exists host_delete_announcement(uuid, uuid);
drop function if exists host_publish_announcement(uuid, text);
drop function if exists host_set_saboteur_phase(uuid, text);
drop function if exists rejoin_saboteur_game(text, text, text);

drop table if exists saboteur_announcements;

drop index if exists saboteur_participants_unique_pin;
drop index if exists saboteur_participants_unique_name;

alter table saboteur_participants drop column if exists pin;
alter table saboteur_games drop column if exists phase;
