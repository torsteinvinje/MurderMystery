-- ============================================================================
-- MIGRASJON 00023 — Poengsløyfa: alle spiller for noe, og noen vinner
--
-- Før dette hang tre systemer løst ved siden av hverandre: sabotørene fikk
-- poeng for mål, de lojale fikk hint (et middel, ikke en belønning),
-- avstemningen hadde ingen konsekvens, og spillet endte uten at noen vant.
-- Poengtavla var i praksis en rangering av hvor godt sabotørene hadde gjort
-- det, mens de lojale ikke satt igjen med noe.
--
-- MOTOREN som innføres her: å fullføre mål gjør deg synlig, og å bli sett
-- koster deg poeng. Det gir sabotøren et ekte valg ved hvert eneste mål, og
-- gjør stemmen til en lojal verdt noe.
--
--   Sabotør:  poeng for fullførte mål
--             + «unnsluppet»-bonus ved spillslutt, som synker for hver stemme
--               hen fikk (5 poeng ved null stemmer, 0 ved fem eller flere)
--   Lojal:    poeng for fullførte oppgaver
--             + poeng for hver stemme på en faktisk sabotør
--   Verten:   kan dele ut bonuspoeng manuelt (beste begrunnelse, kveldens
--             øyeblikk) — bruker 'adjustment', som har ligget ubrukt i
--             poengtabellen siden 00011
--
-- Alt går gjennom det samme append-only poengregisteret, og hver tildeling er
-- idempotent via (source_type, source_id): en stemme kan aldri gi poeng to
-- ganger, uansett hvor mange ganger verten trykker.
--
-- Dessuten:
--   • 1–3 avstemningsrunder, verten bestemmer hvor mange
--   • sabotørmål må være ferdig avgjort før en runde kan åpnes, så poengene
--     er gjort opp når folk stemmer
--   • begrunnelse kan følge stemmen (verten leser dem høyt — samme grep som
--     «beste begrunnelse vinner» i mordmysteriene)
--   • spillerne ser hvor mange stemmer DE selv fikk etter en avsløring
--   • sluttbildet viser sabotørenes mål, lagresultat og kveldens hedersplasser
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) NYE FELTER
-- ----------------------------------------------------------------------------

-- Hvor mange avstemningsrunder kvelden skal ha. Verten bestemmer, 1–3.
alter table saboteur_games add column if not exists max_voting_rounds int not null default 1;
do $$
begin
  alter table saboteur_games add constraint saboteur_games_max_rounds_check
    check (max_voting_rounds between 1 and 3);
exception when duplicate_object then null;
end $$;

-- Oppgaver gir nå poeng, akkurat som mål. Standard 2 — lavere enn et typisk
-- sabotørmål, fordi de lojale også tjener på å stemme riktig.
alter table saboteur_tasks add column if not exists points int not null default 2;
do $$
begin
  alter table saboteur_tasks add constraint saboteur_tasks_points_check check (points >= 0);
exception when duplicate_object then null;
end $$;

-- Begrunnelse med stemmen. Verten leser dem høyt ved avsløringen.
alter table saboteur_ballots add column if not exists reason text;

-- Poengregisteret må kjenne de nye kildene.
alter table saboteur_points_ledger drop constraint if exists saboteur_points_ledger_source_type_check;
alter table saboteur_points_ledger add constraint saboteur_points_ledger_source_type_check
  check (source_type in ('objective', 'task', 'correct_vote', 'undetected', 'adjustment'));

-- ----------------------------------------------------------------------------
-- 2) POENGVERDIER — samlet ett sted, så de er lette å justere etter en test
-- ----------------------------------------------------------------------------

create or replace function _saboteur_points_correct_vote() returns int
language sql immutable as $$ select 3 $$;

-- Bonusen synker lineært med antall stemmer mottatt: 0 stemmer = 5 poeng,
-- 5 eller flere = 0. Å fullføre mål gjør deg synlig; dette er prisen.
create or replace function _saboteur_points_undetected(p_votes int) returns int
language sql immutable as $$ select greatest(0, 5 - coalesce(p_votes, 0)) $$;

revoke execute on function _saboteur_points_correct_vote() from public, anon, authenticated;
revoke execute on function _saboteur_points_undetected(int) from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3) VERTEN STYRER ANTALL RUNDER
-- ----------------------------------------------------------------------------

create or replace function host_set_max_voting_rounds(p_host_token uuid, p_rounds int)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
  v_used int;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if p_rounds is null or p_rounds < 1 or p_rounds > 3 then
    raise exception 'Antall avstemningsrunder må være mellom 1 og 3';
  end if;

  select count(*) into v_used from saboteur_voting_rounds where saboteur_game_id = v_game.id;
  if p_rounds < v_used then
    raise exception 'Dere har allerede hatt % runde(r) — kan ikke sette taket lavere', v_used;
  end if;

  update saboteur_games set max_voting_rounds = p_rounds, updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'set_max_voting_rounds', jsonb_build_object('rounds', p_rounds));
  return json_build_object('ok', true, 'max_voting_rounds', p_rounds);
end $$;

-- ----------------------------------------------------------------------------
-- 4) ÅPNE RUNDE: mål må være gjort opp, og taket må ikke være nådd
-- ----------------------------------------------------------------------------

create or replace function host_open_voting_round(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game      saboteur_games;
  v_round     saboteur_voting_rounds;
  v_used      int;
  v_unsettled int;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status <> 'active' then
    raise exception 'Spillet må være aktivt for å åpne en avstemning';
  end if;

  select count(*) into v_used from saboteur_voting_rounds where saboteur_game_id = v_game.id;
  if v_used >= v_game.max_voting_rounds then
    raise exception 'Dere har brukt alle % avstemningsrundene', v_game.max_voting_rounds;
  end if;

  -- Sabotørmålene skal være ferdige før folk stemmer: da er poengene gjort
  -- opp, og ingen stemmer mens et mål fortsatt kan endre bildet. Utkast
  -- teller ikke — de har spilleren aldri sett.
  select count(*) into v_unsettled
  from saboteur_objectives
  where saboteur_game_id = v_game.id and published and status in ('assigned', 'claimed');
  if v_unsettled > 0 then
    raise exception
      '% sabotørmål er ikke ferdig. Godkjenn eller avslå dem først (eller trekk dem tilbake) før avstemningen åpnes',
      v_unsettled;
  end if;

  begin
    insert into saboteur_voting_rounds (saboteur_game_id) values (v_game.id) returning * into v_round;
  exception when unique_violation then
    raise exception 'Det er allerede en åpen avstemningsrunde';
  end;

  update saboteur_games set status = 'voting', updated_at = now() where id = v_game.id;
  perform _saboteur_audit(v_game.id, 'voting_opened',
    jsonb_build_object('round_id', v_round.id, 'round_number', v_used + 1));
  return json_build_object('ok', true, 'round_id', v_round.id,
    'round_number', v_used + 1, 'of', v_game.max_voting_rounds);
end $$;

-- ----------------------------------------------------------------------------
-- 5) STEMME MED BEGRUNNELSE
-- ----------------------------------------------------------------------------

create or replace function cast_saboteur_ballot(
  p_player_token uuid, p_round_id uuid, p_target_participant_id uuid, p_reason text default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part   saboteur_participants;
  v_round  saboteur_voting_rounds;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);

  if not v_part.active then
    raise exception 'Du kan ikke stemme i denne avstemningen';
  end if;
  if v_reason is not null and length(v_reason) > 300 then
    raise exception 'Begrunnelsen er for lang (maks 300 tegn)';
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
    insert into saboteur_ballots (voting_round_id, voter_participant_id, target_participant_id, reason)
    values (v_round.id, v_part.id, p_target_participant_id, v_reason);
  exception when unique_violation then
    raise exception 'Du har allerede stemt i denne runden';
  end;

  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- 6) POENG FOR OPPGAVER (ved godkjenning)
-- ----------------------------------------------------------------------------

create or replace function host_decide_task_claim(p_host_token uuid, p_task_id uuid, p_approve boolean)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_task     saboteur_tasks;
  v_released int := 0;
  v_waiting  boolean := false;
  v_scored   int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_task from saboteur_tasks where id = p_task_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent oppgave';
  end if;

  if v_task.status in ('approved', 'rejected') then
    return json_build_object('ok', true, 'status', v_task.status, 'already_decided', true);
  end if;
  if v_task.status <> 'claimed' then
    raise exception 'Oppgaven er ikke krevd av spilleren ennå';
  end if;

  if p_approve then
    update saboteur_tasks set status = 'approved', decided_at = now() where id = v_task.id;

    -- Poeng til den lojale. Idempotent på (source_type, source_id).
    insert into saboteur_points_ledger (participant_id, source_type, source_id, points)
    values (v_task.assigned_participant_id, 'task', v_task.id, coalesce(v_task.points, 2))
    on conflict (source_type, source_id) where source_id is not null do nothing;
    get diagnostics v_scored = row_count;

    v_released := _saboteur_release_hint(v_task.id);
    v_waiting := (v_released = 0 and v_task.trigger_objective_id is not null);
  else
    update saboteur_tasks set status = 'rejected', decided_at = now() where id = v_task.id;
  end if;

  perform _saboteur_audit(v_game.id, 'task_decided',
    jsonb_build_object('task_id', v_task.id, 'approved', p_approve,
                       'hints_released', v_released, 'hint_waiting', v_waiting,
                       'points_awarded', v_scored > 0));
  return json_build_object('ok', true,
    'status', case when p_approve then 'approved' else 'rejected' end,
    'hint_waiting', v_waiting, 'points_awarded', v_scored > 0);
end $$;

-- ----------------------------------------------------------------------------
-- 7) POENG FOR RIKTIG STEMME (ved avsløring av runden)
-- ----------------------------------------------------------------------------

create or replace function host_reveal_voting_round(p_host_token uuid, p_round_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   saboteur_games;
  v_round  saboteur_voting_rounds;
  v_scored int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_round from saboteur_voting_rounds where id = p_round_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent avstemningsrunde';
  end if;
  if v_round.status <> 'closed' then
    raise exception 'Lukk runden før den kan avsløres';
  end if;

  update saboteur_voting_rounds set status = 'revealed', revealed_at = now() where id = v_round.id;

  -- Hver LOJAL som pekte på en faktisk sabotør får poeng. Sabotører får ikke
  -- poeng for å stemme «riktig» — de vet jo svaret. Idempotent på stemme-id,
  -- så gjentatt avsløring aldri dobler noe.
  insert into saboteur_points_ledger (participant_id, source_type, source_id, points)
  select b.voter_participant_id, 'correct_vote', b.id, _saboteur_points_correct_vote()
  from saboteur_ballots b
  join saboteur_participants voter  on voter.id  = b.voter_participant_id
  join saboteur_participants target on target.id = b.target_participant_id
  where b.voting_round_id = v_round.id
    and voter.role = 'LOYAL'
    and target.role = 'SABOTEUR'
  on conflict (source_type, source_id) where source_id is not null do nothing;
  get diagnostics v_scored = row_count;

  perform _saboteur_audit(v_game.id, 'voting_revealed',
    jsonb_build_object('round_id', v_round.id, 'correct_votes_scored', v_scored));
  return json_build_object('ok', true, 'correct_votes_scored', v_scored);
end $$;

-- ----------------------------------------------------------------------------
-- 8) «UNNSLUPPET»-BONUS (ved spillslutt)
-- ----------------------------------------------------------------------------

create or replace function host_end_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game    saboteur_games;
  v_sab     record;
  v_votes   int;
  v_bonus   int;
  v_awarded int := 0;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  perform _saboteur_apply_transition(v_game.id, 'ended');

  -- Jo færre stemmer en sabotør fikk gjennom kvelden, jo større bonus.
  for v_sab in
    select id from saboteur_participants
    where saboteur_game_id = v_game.id and role = 'SABOTEUR'
  loop
    select count(*) into v_votes
    from saboteur_ballots b
    join saboteur_voting_rounds r on r.id = b.voting_round_id
    where r.saboteur_game_id = v_game.id and b.target_participant_id = v_sab.id;

    v_bonus := _saboteur_points_undetected(v_votes);
    if v_bonus > 0 then
      insert into saboteur_points_ledger (participant_id, source_type, source_id, points)
      values (v_sab.id, 'undetected', v_sab.id, v_bonus)
      on conflict (source_type, source_id) where source_id is not null do nothing;
      v_awarded := v_awarded + 1;
    end if;
  end loop;

  perform _saboteur_audit(v_game.id, 'undetected_bonuses', jsonb_build_object('awarded', v_awarded));
  return json_build_object('ok', true, 'undetected_bonuses', v_awarded);
end $$;

-- ----------------------------------------------------------------------------
-- 9) VERTENS BONUSPOENG (beste begrunnelse, kveldens øyeblikk …)
-- ----------------------------------------------------------------------------

create or replace function host_award_bonus(
  p_host_token uuid, p_participant_id uuid, p_points int, p_note text default ''
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if p_points is null or p_points = 0 then
    raise exception 'Antall poeng må være forskjellig fra null';
  end if;
  if abs(p_points) > 50 then
    raise exception 'Bonus må være mellom -50 og 50 poeng';
  end if;

  perform 1 from saboteur_participants
  where id = p_participant_id and saboteur_game_id = v_game.id;
  if not found then
    raise exception 'Ukjent deltaker';
  end if;

  -- source_id er null her, så flere bonuser til samme person er lov (unik-
  -- indeksen gjelder bare når source_id finnes).
  insert into saboteur_points_ledger (participant_id, source_type, source_id, points)
  values (p_participant_id, 'adjustment', null, p_points);

  perform _saboteur_audit(v_game.id, 'bonus_awarded',
    jsonb_build_object('participant_id', p_participant_id, 'points', p_points, 'note', coalesce(p_note, '')));
  return json_build_object('ok', true);
end $$;

-- ----------------------------------------------------------------------------
-- 10) VERTSVISNINGEN: runder, begrunnelser, poengoppdeling
-- ----------------------------------------------------------------------------

create or replace function host_get_saboteur_game(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  saboteur_games;
  v_round saboteur_voting_rounds;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  select * into v_round from saboteur_voting_rounds
  where saboteur_game_id = v_game.id order by opened_at desc limit 1;

  return json_build_object(
    'id', v_game.id, 'code', v_game.code, 'title', v_game.title, 'status', v_game.status,
    'phase', v_game.phase, 'intro', v_game.intro,
    'know_each_other', v_game.know_each_other, 'show_leaderboard', v_game.show_leaderboard,
    'max_voting_rounds', v_game.max_voting_rounds,
    'rounds_used', (select count(*) from saboteur_voting_rounds where saboteur_game_id = v_game.id),
    'unsettled_objectives', (
      select count(*) from saboteur_objectives
      where saboteur_game_id = v_game.id and published and status in ('assigned', 'claimed')
    ),
    'created_at', v_game.created_at,

    'participants', (
      select coalesce(json_agg(json_build_object(
        'id', sp.id, 'display_name', sp.display_name, 'role', sp.role, 'active', sp.active,
        'pin', sp.pin,
        'points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = sp.id),
        'points_breakdown', (
          select coalesce(json_object_agg(x.source_type, x.total), '{}'::json)
          from (
            select pl.source_type, sum(pl.points) as total
            from saboteur_points_ledger pl where pl.participant_id = sp.id
            group by pl.source_type
          ) x
        )
      ) order by sp.joined_at), '[]'::json)
      from saboteur_participants sp where sp.saboteur_game_id = v_game.id
    ),

    'announcements', (
      select coalesce(json_agg(json_build_object(
        'id', a.id, 'body', a.body, 'published', a.published,
        'published_at', a.published_at, 'created_at', a.created_at
      ) order by a.created_at desc), '[]'::json)
      from saboteur_announcements a where a.saboteur_game_id = v_game.id
    ),

    'objectives', (
      select coalesce(json_agg(json_build_object(
        'id', o.id, 'participant_id', o.assigned_participant_id, 'title', o.title,
        'description', o.description, 'points', o.points, 'expires_at', o.expires_at,
        'status', o.status, 'claimed_at', o.claimed_at, 'decided_at', o.decided_at,
        'published', o.published, 'published_at', o.published_at
      ) order by o.created_at), '[]'::json)
      from saboteur_objectives o where o.saboteur_game_id = v_game.id
    ),

    'tasks', (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'participant_id', t.assigned_participant_id, 'title', t.title,
        'description', t.description, 'hint_text', t.hint_text, 'hint_audience', t.hint_audience,
        'points', t.points,
        'status', t.status, 'claimed_at', t.claimed_at, 'decided_at', t.decided_at,
        'published', t.published, 'published_at', t.published_at,
        'trigger_objective_id', t.trigger_objective_id,
        'trigger_objective_title', (select o2.title from saboteur_objectives o2 where o2.id = t.trigger_objective_id),
        'trigger_objective_status', (select o2.status from saboteur_objectives o2 where o2.id = t.trigger_objective_id),
        'hint_released', exists (select 1 from saboteur_hint_releases hr where hr.task_id = t.id)
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t where t.saboteur_game_id = v_game.id
    ),

    'current_round', case when v_round.id is null then null else json_build_object(
      'id', v_round.id, 'status', v_round.status,
      'opened_at', v_round.opened_at, 'closed_at', v_round.closed_at, 'revealed_at', v_round.revealed_at,
      'ballot_count', (select count(*) from saboteur_ballots b where b.voting_round_id = v_round.id),
      'tally', case when v_round.status = 'revealed' then (
        select coalesce(json_agg(json_build_object(
          'participant_id', x.target_participant_id, 'display_name', sp.display_name, 'votes', x.votes
        ) order by x.votes desc), '[]'::json)
        from (
          select target_participant_id, count(*) as votes
          from saboteur_ballots where voting_round_id = v_round.id
          group by target_participant_id
        ) x
        join saboteur_participants sp on sp.id = x.target_participant_id
      ) else null end,
      -- Begrunnelsene, til opplesning. Først etter avsløring, som stemmene.
      'reasons', case when v_round.status = 'revealed' then (
        select coalesce(json_agg(json_build_object(
          'voter', voter.display_name, 'target', target.display_name, 'reason', b.reason
        ) order by b.created_at), '[]'::json)
        from saboteur_ballots b
        join saboteur_participants voter  on voter.id  = b.voter_participant_id
        join saboteur_participants target on target.id = b.target_participant_id
        where b.voting_round_id = v_round.id and b.reason is not null
      ) else null end
    ) end
  );
end $$;

-- ----------------------------------------------------------------------------
-- 11) SPILLERENS KORT: framdrift, egne stemmer, og et ordentlig sluttbilde
-- ----------------------------------------------------------------------------

create or replace function get_my_saboteur_brief(p_player_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_part saboteur_participants;
  v_game saboteur_games;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_part := _saboteur_me(p_player_token);
  select * into v_game from saboteur_games where id = v_part.saboteur_game_id;

  return json_build_object(
    'saboteur_game_id', v_game.id, 'code', v_game.code, 'title', v_game.title,
    'status', v_game.status, 'phase', v_game.phase, 'intro', v_game.intro,
    'my_name', v_part.display_name, 'my_role', v_part.role, 'my_active', v_part.active,
    'my_pin', v_part.pin,
    'my_points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = v_part.id),
    'participant_count', (select count(*) from saboteur_participants where saboteur_game_id = v_game.id),

    -- Offentlig framdriftsteller. Røper ingenting om HVEM som har gjort hva,
    -- men gir følelsen av at noe faktisk foregår.
    'completed_count', (
      (select count(*) from saboteur_objectives o
        where o.saboteur_game_id = v_game.id and o.status = 'approved')
      + (select count(*) from saboteur_tasks t
        where t.saboteur_game_id = v_game.id and t.status = 'approved')
    ),

    -- Hvor mange stemmer JEG fikk, i runder som er avslørt. En sabotør som
    -- merker at folk nærmer seg, er en sabotør som må endre oppførsel.
    'votes_against_me', (
      select count(*) from saboteur_ballots b
      join saboteur_voting_rounds r on r.id = b.voting_round_id
      where r.saboteur_game_id = v_game.id and r.status = 'revealed'
        and b.target_participant_id = v_part.id
    ),

    'announcements', (
      select coalesce(json_agg(json_build_object(
        'id', a.id, 'body', a.body, 'created_at', coalesce(a.published_at, a.created_at)
      ) order by coalesce(a.published_at, a.created_at) desc), '[]'::json)
      from saboteur_announcements a
      where a.saboteur_game_id = v_game.id and a.published
    ),

    'fellow_saboteurs', case when v_part.role = 'SABOTEUR' and v_game.know_each_other then (
      select coalesce(json_agg(json_build_object('display_name', sp.display_name)), '[]'::json)
      from saboteur_participants sp
      where sp.saboteur_game_id = v_game.id and sp.role = 'SABOTEUR' and sp.id <> v_part.id
    ) else '[]'::json end,

    'objectives', case when v_part.role = 'SABOTEUR' then (
      select coalesce(json_agg(json_build_object(
        'id', o.id, 'title', o.title, 'description', o.description, 'points', o.points,
        'expires_at', o.expires_at, 'status', o.status
      ) order by o.created_at), '[]'::json)
      from saboteur_objectives o
      where o.assigned_participant_id = v_part.id and o.published
    ) else '[]'::json end,

    'tasks', case when v_part.role = 'LOYAL' then (
      select coalesce(json_agg(json_build_object(
        'id', t.id, 'title', t.title, 'description', t.description,
        'points', t.points, 'status', t.status
      ) order by t.created_at), '[]'::json)
      from saboteur_tasks t
      where t.assigned_participant_id = v_part.id and t.published
    ) else '[]'::json end,

    'hints', (
      select coalesce(json_agg(json_build_object(
        'task_id', hr.task_id,
        'hint_text', coalesce(nullif(hr.hint_text, ''), t.hint_text),
        'released_at', hr.created_at
      ) order by hr.created_at), '[]'::json)
      from saboteur_hint_releases hr join saboteur_tasks t on t.id = hr.task_id
      where hr.released_to_participant_id = v_part.id
    ),

    'reveal', case when v_game.status = 'ended' then json_build_object(
      'participants', (
        select coalesce(json_agg(json_build_object(
          'display_name', sp.display_name, 'role', sp.role,
          'points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = sp.id),
          'votes_received', (
            select count(*) from saboteur_ballots b
            join saboteur_voting_rounds r on r.id = b.voting_round_id
            where r.saboteur_game_id = v_game.id and b.target_participant_id = sp.id
          )
        ) order by sp.display_name), '[]'::json)
        from saboteur_participants sp where sp.saboteur_game_id = v_game.id
      ),

      -- DEN STORE AHA-EN: hva sabotørene faktisk drev med hele kvelden.
      'saboteur_objectives', (
        select coalesce(json_agg(json_build_object(
          'saboteur', sp.display_name, 'title', o.title,
          'points', o.points, 'status', o.status
        ) order by sp.display_name, o.created_at), '[]'::json)
        from saboteur_objectives o
        join saboteur_participants sp on sp.id = o.assigned_participant_id
        where o.saboteur_game_id = v_game.id and o.published
      ),

      -- Lagoppgjør, så de lojale også har noe å vinne sammen.
      'team_scores', (
        select coalesce(json_object_agg(t.role, t.total), '{}'::json)
        from (
          select sp.role, coalesce(sum(pl.points), 0) as total
          from saboteur_participants sp
          left join saboteur_points_ledger pl on pl.participant_id = sp.id
          where sp.saboteur_game_id = v_game.id and sp.role is not null
          group by sp.role
        ) t
      ),

      -- Kveldens hedersplasser.
      'top_saboteur', (
        select json_build_object('display_name', sp.display_name, 'points', coalesce(sum(pl.points), 0))
        from saboteur_participants sp
        left join saboteur_points_ledger pl on pl.participant_id = sp.id
        where sp.saboteur_game_id = v_game.id and sp.role = 'SABOTEUR'
        group by sp.id, sp.display_name
        order by coalesce(sum(pl.points), 0) desc limit 1
      ),
      'top_loyal', (
        select json_build_object('display_name', sp.display_name, 'points', coalesce(sum(pl.points), 0))
        from saboteur_participants sp
        left join saboteur_points_ledger pl on pl.participant_id = sp.id
        where sp.saboteur_game_id = v_game.id and sp.role = 'LOYAL'
        group by sp.id, sp.display_name
        order by coalesce(sum(pl.points), 0) desc limit 1
      ),

      'my_points', (select coalesce(sum(pl.points), 0) from saboteur_points_ledger pl where pl.participant_id = v_part.id),
      'my_breakdown', (
        select coalesce(json_object_agg(x.source_type, x.total), '{}'::json)
        from (
          select pl.source_type, sum(pl.points) as total
          from saboteur_points_ledger pl where pl.participant_id = v_part.id
          group by pl.source_type
        ) x
      ),
      'leaderboard', case when v_game.show_leaderboard then (
        select coalesce(json_agg(json_build_object('display_name', x.display_name, 'points', x.points)
          order by x.points desc), '[]'::json)
        from (
          select sp.display_name, coalesce(sum(pl.points), 0) as points
          from saboteur_participants sp
          left join saboteur_points_ledger pl on pl.participant_id = sp.id
          where sp.saboteur_game_id = v_game.id
          group by sp.id, sp.display_name
        ) x
      ) else null end
    ) else null end
  );
end $$;

-- ---------------------------------------------------------------------------
-- Oppgaver kan nå ha egen poengverdi (som mål alltid har hatt). Verten kan
-- gjøre en vrien oppgave mer verdt enn en enkel.
-- ---------------------------------------------------------------------------
create or replace function host_upsert_task(
  p_host_token uuid, p_task_id uuid default null,
  p_participant_id uuid default null, p_title text default null, p_description text default null,
  p_hint_text text default null, p_hint_audience text default 'assignee',
  p_trigger_objective_id uuid default null, p_points int default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game     saboteur_games;
  v_id       uuid;
  v_title    text := trim(coalesce(p_title, ''));
  v_audience text := coalesce(p_hint_audience, 'assignee');
  v_target   uuid := p_participant_id;
begin
  if not _saboteur_enabled() then raise exception 'Skjult agenda er ikke slått på'; end if;
  v_game := _saboteur_host(p_host_token);

  if v_game.status in ('ended', 'archived') then
    raise exception 'Spillet er avsluttet';
  end if;
  if v_audience not in ('assignee', 'all_loyal') then
    raise exception 'Ukjent mottakergruppe for hintet';
  end if;
  if p_points is not null and (p_points < 0 or p_points > 20) then
    raise exception 'Poeng må være mellom 0 og 20';
  end if;

  -- Utløseren må være et mål i DETTE spillet.
  if p_trigger_objective_id is not null then
    perform 1 from saboteur_objectives
      where id = p_trigger_objective_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent sabotørmål som utløser';
    end if;
  end if;

  if p_task_id is null then
    if v_title = '' then
      raise exception 'Oppgaven trenger en tittel';
    end if;

    if v_target is null then
      v_target := _saboteur_random_participant(v_game.id, 'LOYAL');
      if v_target is null then
        raise exception 'Ingen aktiv Lojal å tildele oppgaven til';
      end if;
    else
      perform 1 from saboteur_participants
        where id = v_target and saboteur_game_id = v_game.id and role = 'LOYAL';
      if not found then
        raise exception 'Oppgaven må tildeles en Lojal i dette spillet';
      end if;
    end if;

    insert into saboteur_tasks (saboteur_game_id, assigned_participant_id, title, description,
                                hint_text, hint_audience, trigger_objective_id, points)
    values (v_game.id, v_target, v_title, coalesce(p_description, ''), coalesce(p_hint_text, ''),
            v_audience, p_trigger_objective_id, coalesce(p_points, 2))
    returning id into v_id;
  else
    update saboteur_tasks set
      title                = coalesce(nullif(trim(p_title), ''), title),
      description          = coalesce(p_description, description),
      hint_text            = coalesce(p_hint_text, hint_text),
      hint_audience        = coalesce(p_hint_audience, hint_audience),
      points               = coalesce(p_points, points),
      -- Null her betyr «ikke endre». Bruk den dedikerte funksjonen under for
      -- å fjerne en kobling.
      trigger_objective_id = coalesce(p_trigger_objective_id, trigger_objective_id)
    where id = p_task_id and saboteur_game_id = v_game.id;
    if not found then
      raise exception 'Ukjent oppgave';
    end if;
    v_id := p_task_id;
  end if;

  perform _saboteur_audit(v_game.id, 'task_upsert',
    jsonb_build_object('task_id', v_id, 'trigger_objective_id', p_trigger_objective_id));
  return json_build_object('ok', true, 'id', v_id);
end $$;

-- Gammel 3-argumentsversjon må bort, ellers blir kallet tvetydig.
drop function if exists cast_saboteur_ballot(uuid, uuid, uuid);
-- Samme for 8-argumentsversjonen av oppgave-lagringen.
drop function if exists host_upsert_task(uuid, uuid, uuid, text, text, text, text, uuid);

grant execute on function host_set_max_voting_rounds(uuid, int) to anon, authenticated;
grant execute on function host_award_bonus(uuid, uuid, int, text) to anon, authenticated;
grant execute on function cast_saboteur_ballot(uuid, uuid, uuid, text) to anon, authenticated;
grant execute on function host_upsert_task(uuid, uuid, uuid, text, text, text, text, uuid, int) to anon, authenticated;

select record_migration('00023_scoring_loop', 'poeng til alle, lagresultat, 1-3 runder, begrunnelser');
