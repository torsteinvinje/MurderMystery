-- ============================================================================
-- MIGRASJON 00018 — Slett sabotørmål og oppgaver
--
-- Verten kunne opprette og endre mål/oppgaver, men aldri fjerne dem. Et
-- feilplassert mål ble dermed liggende ut kvelden.
--
-- To ting er verdt å vite om sletting:
--
-- 1) POENG FØLGER MED. Slettes et GODKJENT mål, fjernes også poengene det ga
--    (saboteur_points_ledger har ingen fremmednøkkel til målet, så det må
--    gjøres eksplisitt). Alternativet — å la poeng bli liggende for et mål
--    ingen lenger kan se — ville gjort poengtavla umulig å forklare.
--
-- 2) HINT-KOBLINGER OVERLEVER. Sletter du et mål som utløser et hint, settes
--    koblingen til null (fremmednøkkelen er «on delete set null» fra 00017),
--    og hintet blir et vanlig hint i stedet for å forsvinne. Allerede utdelte
--    hint tas aldri tilbake — deltakerne har jo lest dem.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create or replace function host_delete_objective(p_host_token uuid, p_objective_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game    saboteur_games;
  v_obj     saboteur_objectives;
  v_points  int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_obj from saboteur_objectives
  where id = p_objective_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent mål';
  end if;

  -- Fjern poeng målet eventuelt har gitt, så poengtavla forblir forklarlig.
  delete from saboteur_points_ledger
  where source_type = 'objective' and source_id = v_obj.id;
  get diagnostics v_points = row_count;

  -- Hint som ventet på dette målet mister utløseren sin (on delete set null)
  -- og oppfører seg deretter som et vanlig hint.
  delete from saboteur_objectives where id = v_obj.id;

  perform _saboteur_audit(v_game.id, 'objective_deleted',
    jsonb_build_object('objective_id', v_obj.id, 'title', v_obj.title,
                       'points_reverted', v_points > 0));
  return json_build_object('ok', true, 'points_reverted', v_points > 0);
end $$;

create or replace function host_delete_task(p_host_token uuid, p_task_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_task saboteur_tasks;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_task from saboteur_tasks where id = p_task_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent oppgave';
  end if;

  -- saboteur_hint_releases har «on delete cascade» mot oppgaven, så et hint
  -- som allerede er delt ut forsvinner fra spillerens kort sammen med
  -- oppgaven. Det er med vilje: sletter du oppgaven, fjernes hele sporet.
  delete from saboteur_tasks where id = v_task.id;

  perform _saboteur_audit(v_game.id, 'task_deleted',
    jsonb_build_object('task_id', v_task.id, 'title', v_task.title));
  return json_build_object('ok', true);
end $$;

grant execute on function host_delete_objective(uuid, uuid) to anon, authenticated;
grant execute on function host_delete_task(uuid, uuid) to anon, authenticated;
