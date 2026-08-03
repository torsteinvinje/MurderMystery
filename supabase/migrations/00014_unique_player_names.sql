-- ============================================================================
-- MIGRASJON 00014 — Unike gjestenavn per festkode (mordmysteriet)
--
-- Samme begrunnelse som for Skjult agenda: to gjester med samme navn gjør
-- vertens spillerliste umulig å lese — man vet ikke hvem man deler ut hvilken
-- rolle til.
--
-- Bevisst forsiktig her, i motsetning til i Skjult agenda: dette er en tabell
-- med ekte fester i, som kan ha duplikater fra før. Derfor sjekkes navnet i
-- join_game (som er den eneste veien inn i players), og det legges IKKE på en
-- unik indeks — en indeks ville feilet på eksisterende data og blokkert hele
-- migrasjonen. Eksisterende fester med duplikatnavn fortsetter altså å virke;
-- det er bare nye innmeldinger som må ha unikt navn.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create or replace function join_game(p_code text, p_name text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game   games;
  v_player players;
  v_name   text := trim(coalesce(p_name, ''));
  v_code   text := upper(trim(coalesce(p_code, '')));
begin
  if v_name = '' then
    raise exception 'Du må skrive inn et navn';
  end if;
  if length(v_name) > 40 then
    raise exception 'Navnet er for langt (maks 40 tegn)';
  end if;

  select * into v_game from games where code = v_code;
  if not found then
    raise exception 'Fant ingen fest med koden «%»', v_code;
  end if;
  if v_game.status in ('revealed', 'finished') then
    raise exception 'Denne festen er avsluttet';
  end if;

  if exists (
    select 1 from players
    where game_id = v_game.id and lower(display_name) = lower(v_name)
  ) then
    raise exception 'Navnet «%» er allerede i bruk på denne festen — velg et annet', v_name;
  end if;

  insert into players (game_id, display_name)
  values (v_game.id, v_name)
  returning * into v_player;

  perform _poke(v_game.id, 'players');

  return json_build_object(
    'player_token', v_player.player_token,
    'player_id', v_player.id,
    'game_id', v_game.id,
    'code', v_game.code
  );
end $$;

grant execute on function join_game(text, text) to anon, authenticated;
