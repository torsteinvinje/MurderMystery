-- ============================================================================
-- MIGRASJON 00008 — Fjern den separate «Bevis»/Evidence-funksjonen
--
-- «Polaroider» heter nå «Bevis» i grensesnittet, så den egne evidence-fanen
-- er overflødig. Denne migrasjonen fjerner den fra databasen.
--
-- OBS: dette sletter evidence-tabellen og alt innhold i den. Det er meningen —
-- funksjonen er tatt ut. Polaroidene (som nå heter «Bevis») er en egen tabell
-- og røres ikke.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

drop function if exists host_list_evidence(uuid);
drop function if exists host_add_evidence(uuid, text, text, text);
drop function if exists host_delete_evidence(uuid, uuid);

drop table if exists evidence;
