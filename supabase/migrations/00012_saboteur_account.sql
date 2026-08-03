-- ============================================================================
-- MIGRASJON 00012 — Skjult agenda: knytt spill til vertskontoen
--
-- Problemet dette løser: vertsnøkkelen har bare ligget i localStorage. Bytter
-- verten telefon, tømmer nettleseren eller åpner spillet i inkognito, er
-- spillet borte for godt — selv om det står og går fint i databasen.
--
-- Med innlogging får verten samme opplevelse som resten av appen: spillene
-- dine følger kontoen din, ikke enheten. create_saboteur_game setter allerede
-- owner_id = auth.uid() (fra 00011), så det som mangler er å kunne LISTE og
-- GJENOPPTA dem — pluss å kunne knytte til et spill man laget før man logget inn.
--
-- Sikkerhet:
--   - Begge funksjonene krever innlogging (auth.uid() må finnes).
--   - owner_list_saboteur_games returnerer KUN rader der owner_id = auth.uid().
--     Den returnerer host_token for disse — det er trygt, for det er nettopp
--     verten sitt eget spill; nøkkelen er den samme de allerede hadde lokalt.
--   - owner_claim_saboteur_game krever at du oppgir host_token. Den som har
--     vertsnøkkelen kontrollerer allerede spillet fullt ut, så å la dem knytte
--     det til egen konto gir ingen ny tilgang. Et spill som allerede eies av
--     en ANNEN konto kan ikke overtas.
--   - Som alt annet her: funksjonsflagget sjekkes først.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- Mine Skjult agenda-spill (krever innlogging).
create or replace function owner_list_saboteur_games()
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;

  return (
    select coalesce(json_agg(json_build_object(
      'saboteur_game_id', g.id,
      'code', g.code,
      'title', g.title,
      'status', g.status,
      'host_token', g.host_token,
      'participant_count', (select count(*) from saboteur_participants sp where sp.saboteur_game_id = g.id),
      'created_at', g.created_at
    ) order by g.created_at desc), '[]'::json)
    from saboteur_games g
    where g.owner_id = v_uid and g.status <> 'archived'
  );
end $$;

-- Knytt et spill du allerede har vertsnøkkelen til, til kontoen din.
create or replace function owner_claim_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;

  v_game := _saboteur_host(p_host_token);

  if v_game.owner_id is not null and v_game.owner_id <> v_uid then
    raise exception 'Spillet tilhører allerede en annen konto';
  end if;

  update saboteur_games set owner_id = v_uid, updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'claimed_by_account', '{}'::jsonb);
  return json_build_object('ok', true, 'saboteur_game_id', v_game.id);
end $$;

grant execute on function owner_list_saboteur_games() to authenticated;
grant execute on function owner_claim_saboteur_game(uuid) to authenticated;
