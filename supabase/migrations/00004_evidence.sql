-- ============================================================================
-- MIGRASJON 00004 — Bevis (Evidence)
--
-- En egen, vertsstyrt bevisboks per fest — atskilt fra polaroidene.
--   * Polaroider = ledetråder verten AVSLØRER for gjestene under spillet.
--   * Bevis      = vertens PRIVATE saksmappe (vises aldri til gjestene).
--
-- Følger nøyaktig samme mønster som resten av modellen: RLS på uten policies,
-- all tilgang via SECURITY DEFINER-RPC-er som validerer host_token. Bevis er
-- knyttet til en fest (game_id); festen er igjen knyttet til en konto via
-- games.owner_id (fase A), så håndhevet konto-eierskap i fase B arver dette.
--
-- Trygg å kjøre flere ganger.
-- ============================================================================

create table if not exists evidence (
  id          uuid primary key default gen_random_uuid(),
  game_id     uuid not null references games (id) on delete cascade,
  sort_order  int  not null default 0,
  title       text not null default '',
  description text not null default '',
  image_url   text,
  created_at  timestamptz not null default now()
);

create index if not exists evidence_game_idx on evidence (game_id, sort_order);

alter table evidence enable row level security;
-- Ingen policies: klienten når aldri tabellen direkte. Fjern rettigheter for
-- sikkerhets skyld (belte og bukseseler).
revoke all on evidence from anon, authenticated;

-- ----------------------------------------------------------------------------
-- RPC-er (kun vert, validert med host_token via _host_game)
-- ----------------------------------------------------------------------------

create or replace function host_list_evidence(p_host_token uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  return (
    select coalesce(json_agg(json_build_object(
      'id', e.id, 'sort_order', e.sort_order, 'title', e.title,
      'description', e.description, 'image_url', e.image_url, 'created_at', e.created_at
    ) order by e.sort_order, e.created_at), '[]'::json)
    from evidence e
    where e.game_id = v_game.id
  );
end $$;

create or replace function host_add_evidence(
  p_host_token uuid, p_title text, p_description text default null, p_image_url text default null
)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game  games := _host_game(p_host_token);
  v_title text := trim(coalesce(p_title, ''));
  v_id    uuid;
begin
  if v_title = '' then
    raise exception 'Beviset trenger en tittel';
  end if;
  if length(v_title) > 160 then
    raise exception 'Tittelen er for lang (maks 160 tegn)';
  end if;

  insert into evidence (game_id, title, description, image_url, sort_order)
  values (
    v_game.id, v_title, coalesce(p_description, ''), nullif(trim(coalesce(p_image_url, '')), ''),
    (select coalesce(max(sort_order), 0) + 1 from evidence where game_id = v_game.id)
  )
  returning id into v_id;

  perform _poke(v_game.id, 'evidence');
  return json_build_object('ok', true, 'id', v_id);
end $$;

create or replace function host_delete_evidence(p_host_token uuid, p_evidence_id uuid)
returns json
language plpgsql security definer set search_path = public
as $$
declare
  v_game games := _host_game(p_host_token);
begin
  delete from evidence where id = p_evidence_id and game_id = v_game.id;
  if not found then
    raise exception 'Ukjent bevis';
  end if;

  perform _poke(v_game.id, 'evidence');
  return json_build_object('ok', true);
end $$;

grant execute on function host_list_evidence(uuid) to anon, authenticated;
grant execute on function host_add_evidence(uuid, text, text, text) to anon, authenticated;
grant execute on function host_delete_evidence(uuid, uuid) to anon, authenticated;
