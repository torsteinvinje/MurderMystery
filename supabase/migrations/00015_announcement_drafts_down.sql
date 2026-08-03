-- ============================================================================
-- MIGRASJON 00015 (NED) — tilbake til «send og slett»
--
-- Fjerner utkast/redigering. ADVARSEL: upubliserte utkast blir synlige for
-- alle når published-kolonnen forsvinner, siden filteret da ikke finnes. Slett
-- eventuelle utkast FØR du kjører denne:
--   delete from saboteur_announcements where not published;
--
-- Kjør 00013 på nytt etterpå for å få tilbake host_publish_announcement og de
-- gamle versjonene av host_get_saboteur_game / get_my_saboteur_brief.
-- ============================================================================

drop function if exists host_set_announcement_published(uuid, uuid, boolean);
drop function if exists host_upsert_announcement(uuid, uuid, text);

alter table saboteur_announcements drop column if exists published_at;
alter table saboteur_announcements drop column if exists published;
