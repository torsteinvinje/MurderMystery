-- Reverserer 00018. Sletter ingen data; fjerner kun de to funksjonene.
drop function if exists host_delete_task(uuid, uuid);
drop function if exists host_delete_objective(uuid, uuid);
