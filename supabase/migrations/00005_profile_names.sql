-- ============================================================================
-- MIGRASJON 00005 — Fornavn og etternavn på profilen
--
-- Deler visningsnavnet i fornavn + etternavn, og lar en innlogget vert endre
-- navnet sitt. display_name beholdes (utledet som «Fornavn Etternavn») og er
-- det som vises f.eks. øverst til høyre i menyen.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

alter table profiles add column if not exists first_name text not null default '';
alter table profiles add column if not exists last_name  text not null default '';

-- Opprett profil ved registrering: hent fornavn/etternavn fra metadata og bygg
-- display_name. Faller tilbake til et evt. eldre display_name-metadatafelt.
create or replace function handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_first text := coalesce(new.raw_user_meta_data ->> 'first_name', '');
  v_last  text := coalesce(new.raw_user_meta_data ->> 'last_name', '');
begin
  insert into public.profiles (id, first_name, last_name, display_name)
  values (
    new.id, v_first, v_last,
    coalesce(
      nullif(trim(v_first || ' ' || v_last), ''),
      new.raw_user_meta_data ->> 'display_name',
      ''
    )
  )
  on conflict (id) do nothing;
  return new;
end $$;

-- Profilen til den innloggede verten (til kontosiden + menyen).
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
    'first_name', coalesce(v_row.first_name, ''),
    'last_name', coalesce(v_row.last_name, ''),
    'display_name', coalesce(v_row.display_name, '')
  );
end $$;

-- La verten oppdatere navnet sitt (fornavn + etternavn).
create or replace function update_my_profile(p_first text, p_last text)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_first text := trim(coalesce(p_first, ''));
  v_last  text := trim(coalesce(p_last, ''));
begin
  if v_uid is null then
    raise exception 'Ikke innlogget';
  end if;
  if v_first = '' or v_last = '' then
    raise exception 'Fyll inn både fornavn og etternavn';
  end if;
  if length(v_first) > 60 or length(v_last) > 60 then
    raise exception 'Navnet er for langt (maks 60 tegn per felt)';
  end if;

  update profiles
     set first_name = v_first, last_name = v_last,
         display_name = trim(v_first || ' ' || v_last)
   where id = v_uid;

  if not found then
    insert into profiles (id, first_name, last_name, display_name)
    values (v_uid, v_first, v_last, trim(v_first || ' ' || v_last));
  end if;

  return json_build_object('ok', true, 'display_name', trim(v_first || ' ' || v_last));
end $$;

grant execute on function get_my_profile() to authenticated;
grant execute on function update_my_profile(text, text) to authenticated;
