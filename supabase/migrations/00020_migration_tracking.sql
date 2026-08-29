-- ============================================================================
-- MIGRASJON 00020 — Hold styr på hvilke migrasjoner som er kjørt
--
-- Problemet dette løser: prosjektet har hatt 19 migrasjonsfiler og INGEN måte
-- å vite hvilke som faktisk er kjørt i en gitt database. «Kjørte jeg 00015?»
-- har bare kunnet besvares ved å prøve seg fram — og en glemt migrasjon ser
-- ut som en ødelagt funksjon, ikke som en manglende oppdatering. Det har
-- kostet flere feilsøkingsrunder.
--
-- Herfra: hver migrasjon avslutter med å registrere seg selv, og
-- `select * from schema_migrations order by version;` svarer på spørsmålet.
--
-- Denne fila registrerer også ALLE tidligere migrasjoner (00001–00019). Det
-- er en bevisst antakelse: kjører du denne, har du en database som allerede
-- er oppdatert. Stemmer ikke det, kjør supabase-schema.sql først — den er
-- komplett og idempotent — og deretter denne.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create table if not exists schema_migrations (
  version     text primary key,          -- filnavnet uten .sql, f.eks. '00015_announcement_drafts'
  applied_at  timestamptz not null default now(),
  note        text not null default ''
);

alter table schema_migrations enable row level security;
revoke all on schema_migrations from anon, authenticated;

-- Registrer en migrasjon. Kalles på slutten av hver migrasjonsfil.
create or replace function record_migration(p_version text, p_note text default '')
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into schema_migrations (version, note)
  values (p_version, coalesce(p_note, ''))
  on conflict (version) do nothing;   -- kjørt før: ikke flytt tidspunktet
end $$;

revoke execute on function record_migration(text, text) from public, anon, authenticated;

-- Hvilke migrasjoner mangler? Sammenlign lista under med filene i
-- supabase/migrations/. Kjør:
--     select * from missing_migrations();
-- Tom liste = databasen er à jour.
create or replace function missing_migrations()
returns table (version text, status text)
language plpgsql security definer set search_path = public
as $$
declare
  -- Kjent historikk per 00020. Nye migrasjoner MÅ legges til her i tillegg
  -- til å kalle record_migration(), ellers vet ikke denne funksjonen om dem.
  v_known text[] := array[
    '00001_init',
    '00002_mysteries',
    '00003_auth',
    '00004_evidence',
    '00005_profile_names',
    '00006_two_new_mysteries',
    '00007_runbooks',
    '00008_remove_evidence',
    '00009_saboteur_game',
    '00010_saboteur_discovery',
    '00011_saboteur_standalone',
    '00012_saboteur_account',
    '00013_saboteur_pins_phases',
    '00014_unique_player_names',
    '00015_announcement_drafts',
    '00016_saboteur_intro_library',
    '00017_hint_trigger',
    '00018_delete_objectives_tasks',
    '00019_task_and_hint_libraries',
    '00020_migration_tracking',
    '00021_everyone_votes'
  ];
  v_version text;
begin
  foreach v_version in array v_known loop
    if not exists (select 1 from schema_migrations sm where sm.version = v_version) then
      version := v_version;
      status  := 'IKKE KJØRT — kjør supabase/migrations/' || v_version || '.sql';
      return next;
    end if;
  end loop;
end $$;

grant execute on function missing_migrations() to anon, authenticated;

-- ----------------------------------------------------------------------------
-- Registrer historikken. Se hovedkommentaren over for antakelsen som gjøres.
-- ----------------------------------------------------------------------------

do $$
declare
  v_version text;
  v_all text[] := array[
    '00001_init', '00002_mysteries', '00003_auth', '00004_evidence',
    '00005_profile_names', '00006_two_new_mysteries', '00007_runbooks',
    '00008_remove_evidence', '00009_saboteur_game', '00010_saboteur_discovery',
    '00011_saboteur_standalone', '00012_saboteur_account',
    '00013_saboteur_pins_phases', '00014_unique_player_names',
    '00015_announcement_drafts', '00016_saboteur_intro_library',
    '00017_hint_trigger', '00018_delete_objectives_tasks',
    '00019_task_and_hint_libraries'
  ];
begin
  foreach v_version in array v_all loop
    perform record_migration(v_version, 'registrert i etterkant av 00020');
  end loop;
end $$;

select record_migration('00020_migration_tracking', 'innfører migrasjonssporing');
