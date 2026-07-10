-- ============================================================================
-- MIGRASJON 00003 — Vertskontoer (Supabase Auth, «lag på toppen»)
--
-- Legger til ekte innlogging for verter UTEN å rive ut den fungerende
-- token-modellen: spill og mysterier styres fortsatt av hemmelige tokens i
-- nettleseren, men når en INNLOGGET vert oppretter noe, knyttes det nå også
-- til brukerkontoen (owner_id -> auth.users). Anonyme verter fungerer som før
-- (owner_id blir da null).
--
-- Denne migrasjonen håndterer autentisering (hvem du er). Autorisasjon (hvem
-- som får se/endre hva) håndheves i en senere migrasjon — se planen i README.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) PROFILER — offentlig-trygg utvidelse av auth.users
--    (Vi kopierer ALDRI passord eller tokens hit. Kun visningsnavn o.l.)
-- ----------------------------------------------------------------------------

create table if not exists profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  created_at   timestamptz not null default now()
);

alter table profiles enable row level security;

-- En innlogget bruker kan lese og endre KUN sin egen profil.
drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
  for select to authenticated using (id = auth.uid());

drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Ingen INSERT/DELETE-policy: rader opprettes av triggeren under (security
-- definer) og slettes via cascade når brukeren slettes.

-- Opprett en profil automatisk når en ny bruker registrerer seg. Visningsnavnet
-- tas fra metadata klienten sendte ved registrering (raw_user_meta_data).
create or replace function handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ----------------------------------------------------------------------------
-- 2) EIERSKAP — knytt spill og mysterier til en konto (nullbart)
-- ----------------------------------------------------------------------------

alter table games     add column if not exists owner_id uuid references auth.users (id) on delete set null;
alter table mysteries add column if not exists owner_id uuid references auth.users (id) on delete set null;

create index if not exists games_owner_idx     on games (owner_id);
create index if not exists mysteries_owner_idx on mysteries (owner_id);

-- ----------------------------------------------------------------------------
-- 3) Sett owner_id ved opprettelse (auth.uid() virker også i SECURITY DEFINER:
--    den leser innloggingsclaimet fra forespørselen, ikke funksjonens rolle).
--    Anonyme kall gir auth.uid() = null, altså samme oppførsel som før.
-- ----------------------------------------------------------------------------

create or replace function create_game(p_mystery_id uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_mystery  mysteries;
  v_game     games;
  v_code     text;
  v_chars    text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_suspects int;
  v_killers  int;
begin
  if p_mystery_id is null then
    select * into v_mystery from mysteries where is_builtin order by created_at limit 1;
  else
    select * into v_mystery from mysteries where id = p_mystery_id;
  end if;
  if v_mystery.id is null then
    raise exception 'Fant ikke mysteriet';
  end if;

  select count(*), count(*) filter (where is_killer)
    into v_suspects, v_killers
  from mystery_suspects where mystery_id = v_mystery.id;
  if v_suspects < 2 then
    raise exception 'Mysteriet «%» trenger minst to mistenkte før det kan spilles', v_mystery.title;
  end if;
  if v_killers <> 1 then
    raise exception 'Mysteriet «%» må ha nøyaktig én morder (har %)', v_mystery.title, v_killers;
  end if;

  loop
    select string_agg(substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1), '')
      into v_code
      from generate_series(1, 4);
    exit when not exists (select 1 from games where code = v_code);
  end loop;

  insert into games (code, mystery_id, title, intro, resolution, owner_id)
  values (v_code, v_mystery.id, v_mystery.title, v_mystery.intro, v_mystery.resolution, auth.uid())
  returning * into v_game;

  insert into suspects (game_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
  select v_game.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
  from mystery_suspects s
  where s.mystery_id = v_mystery.id;

  insert into polaroids (game_id, sort_order, title, caption, image_url)
  select v_game.id, p.sort_order, p.title, p.caption, p.image_url
  from mystery_polaroids p
  where p.mystery_id = v_mystery.id;

  perform _poke(v_game.id, 'game');

  return json_build_object(
    'game_id', v_game.id,
    'code', v_game.code,
    'host_token', v_game.host_token
  );
end $$;

create or replace function create_mystery(p_title text, p_copy_from uuid default null)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_title text := trim(coalesce(p_title, ''));
  v_src   mysteries;
  v_new   mysteries;
begin
  if v_title = '' then
    raise exception 'Mysteriet trenger en tittel';
  end if;
  if length(v_title) > 120 then
    raise exception 'Tittelen er for lang (maks 120 tegn)';
  end if;

  if p_copy_from is not null then
    select * into v_src from mysteries where id = p_copy_from and is_builtin;
    if not found then
      raise exception 'Du kan bare kopiere fra de innebygde mysteriene';
    end if;
  end if;

  insert into mysteries (title, intro, resolution, owner_id)
  values (v_title, coalesce(v_src.intro, ''), coalesce(v_src.resolution, ''), auth.uid())
  returning * into v_new;

  if v_src.id is not null then
    insert into mystery_suspects (mystery_id, sort_order, name, tagline, public_info, secret, alibi, is_killer)
    select v_new.id, s.sort_order, s.name, s.tagline, s.public_info, s.secret, s.alibi, s.is_killer
    from mystery_suspects s where s.mystery_id = v_src.id;

    insert into mystery_polaroids (mystery_id, sort_order, title, caption, image_url)
    select v_new.id, p.sort_order, p.title, p.caption, p.image_url
    from mystery_polaroids p where p.mystery_id = v_src.id;
  end if;

  return json_build_object(
    'mystery_id', v_new.id,
    'owner_token', v_new.owner_token,
    'title', v_new.title
  );
end $$;

grant execute on function create_game(uuid) to anon, authenticated;
grant execute on function create_mystery(text, uuid) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4) La en innlogget vert hente sin egen profil (til kontosiden).
-- ----------------------------------------------------------------------------

create or replace function get_my_profile()
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row profiles;
begin
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;
  select * into v_row from profiles where id = v_uid;
  return json_build_object(
    'id', v_uid,
    'display_name', coalesce(v_row.display_name, '')
  );
end $$;

grant execute on function get_my_profile() to authenticated;
