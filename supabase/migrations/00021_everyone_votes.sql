-- ============================================================================
-- MIGRASJON 00021 — Alle deltakere kan stemme, ikke bare de lojale
--
-- Før kunne kun Lojale stemme. Det avslørte rollene: en sabotør som ikke fikk
-- opp stemmeskjemaet visste at de andre kunne se at hen ikke stemte, og en
-- lojal kunne slutte seg til hvem som IKKE hadde stemt. I skjult-identitet-
-- spill stemmer alle — sabotørene stemmer også, og lyver mens de gjør det.
--
-- Endringen er å fjerne rollekravet tre steder. Alt annet står:
--   • fortsatt én stemme per deltaker per runde (unik indeks i databasen)
--   • fortsatt bare mens runden er åpen
--   • fortsatt hemmelig til verten både lukker OG avslører runden
--   • inaktive deltakere kan fortsatt ikke stemme
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create or replace function get_my_saboteur_vote_status(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
  v_voted boolean := false;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_part.saboteur_game_id and status = 'open' limit 1;

  if v_round.id is not null then
    select exists(
      select 1 from saboteur_ballots where voting_round_id = v_round.id and voter_participant_id = v_part.id
    ) into v_voted;
  end if;

  -- Ingen rollesjekk: alle aktive deltakere stemmer, uansett rolle.
  return json_build_object(
    'can_vote', v_round.id is not null and v_part.active and not v_voted,
    'round_open', v_round.id is not null, 'round_id', v_round.id, 'already_voted', v_voted
  );
end $$;

create or replace function get_saboteur_ballot_targets(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_part.saboteur_game_id and status = 'open' limit 1;

  if v_round.id is null or not v_part.active then
    return '[]'::json;
  end if;

  -- Alle aktive deltakere kan stemmes på, inkludert en selv. Å stemme på seg
  -- selv er et fullt legitimt trekk for en sabotør som vil virke uskyldig.
  return (
    select coalesce(json_agg(json_build_object('participant_id', sp.id, 'display_name', sp.display_name)
      order by sp.display_name), '[]'::json)
    from saboteur_participants sp
    where sp.saboteur_game_id = v_part.saboteur_game_id and sp.active
  );
end $$;

create or replace function cast_saboteur_ballot(p_player_token uuid, p_round_id uuid, p_target_participant_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part  saboteur_participants;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  if not v_part.active then
    raise exception 'Du kan ikke stemme i denne avstemningen';
  end if;

  select * into v_round from saboteur_voting_rounds
  where id = p_round_id and saboteur_game_id = v_part.saboteur_game_id and status = 'open';
  if not found then
    raise exception 'Avstemningen er ikke åpen';
  end if;

  perform 1 from saboteur_participants
  where id = p_target_participant_id and saboteur_game_id = v_part.saboteur_game_id and active;
  if not found then
    raise exception 'Ukjent stemmemål';
  end if;

  begin
    insert into saboteur_ballots (voting_round_id, voter_participant_id, target_participant_id)
    values (v_round.id, v_part.id, p_target_participant_id);
  exception when unique_violation then
    raise exception 'Du har allerede stemt i denne runden';
  end;

  return json_build_object('ok', true);
end $$;

select record_migration('00021_everyone_votes', 'alle deltakere kan stemme, ikke bare lojale');
