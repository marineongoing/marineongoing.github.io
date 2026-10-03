-- Mon quotidien : tables et fonctions
-- À copier-coller en entier dans Supabase > SQL Editor > New query, puis Run.
-- Ce script ne touche pas à ta table "docs" de l'app BTS NDRC.
-- Si tu as déjà lancé la première version, relance simplement celle-ci : elle ajoute ce qui manque.

create extension if not exists pgcrypto with schema extensions;

-- Une ligne par jour : humeur, eau, pas, sommeil, règles, notes
create table if not exists public.vie_days (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  day date not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);
alter table public.vie_days enable row level security;
drop policy if exists "vie_days : mes lignes" on public.vie_days;
create policy "vie_days : mes lignes" on public.vie_days
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Réglages (prénom, objectifs, fond, bilans de Claude)
create table if not exists public.vie_prefs (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.vie_prefs enable row level security;
drop policy if exists "vie_prefs : mes réglages" on public.vie_prefs;
create policy "vie_prefs : mes réglages" on public.vie_prefs
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Éléments de l'app : tâches, dépenses, revenus, événements, certificats, contacts, objectifs
create table if not exists public.vie_items (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  id text not null,
  kind text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.vie_items enable row level security;
drop policy if exists "vie_items : mes éléments" on public.vie_items;
create policy "vie_items : mes éléments" on public.vie_items
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Clé privée du raccourci iPhone (seule son empreinte est stockée)
create table if not exists public.vie_tokens (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now()
);
alter table public.vie_tokens enable row level security;
drop policy if exists "vie_tokens : ma clé" on public.vie_tokens;
create policy "vie_tokens : ma clé" on public.vie_tokens
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Enregistrement depuis l'app : fusionne les champs modifiés avec ceux du jour
create or replace function public.vie_save(p_day date, p_patch jsonb)
returns void language sql security invoker set search_path = public as $$
  insert into public.vie_days (user_id, day, data)
  values (auth.uid(), p_day, p_patch)
  on conflict (user_id, day) do update
    set data = public.vie_days.data || excluded.data, updated_at = now();
$$;
revoke all on function public.vie_save(date, jsonb) from public, anon;
grant execute on function public.vie_save(date, jsonb) to authenticated;

-- Réception depuis le raccourci iPhone (pas, sommeil, règles venant d'Apple Santé)
create or replace function public.vie_import(
  p_token text,
  p_day date default null,
  p_steps numeric default null,
  p_sleep numeric default null,
  p_flow text default null
) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  uid uuid;
  d date := coalesce(p_day, (now() at time zone 'Europe/Paris')::date);
  patch jsonb := '{}'::jsonb;
  src jsonb := '{}'::jsonb;
  f text := lower(coalesce(p_flow, ''));
  sl numeric := p_sleep;
  msg text[] := '{}';
begin
  select user_id into uid from public.vie_tokens
   where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
  if uid is null then raise exception 'Clé invalide : recrée-la dans les réglages de Mon quotidien'; end if;
  if d > current_date + 1 or d < current_date - 90 then raise exception 'Date invalide'; end if;

  if p_steps is not null and p_steps >= 0 and p_steps < 200000 then
    patch := patch || jsonb_build_object('steps', round(p_steps));
    src := src || '{"steps":"sante"}';
    msg := msg || (round(p_steps)::text || ' pas');
  end if;

  -- Le sommeil peut arriver en heures, en minutes ou en secondes selon le raccourci
  if sl is not null and sl > 0 then
    if sl > 1440 then sl := sl / 3600; elsif sl > 24 then sl := sl / 60; end if;
    if sl <= 24 then
      patch := patch || jsonb_build_object('sleep', (round(sl * 4) / 4)::numeric(5,2));
      src := src || '{"sleep":"sante"}';
      msg := msg || (replace(to_char(round(sl * 4) / 4, 'FM90.99'), '.', ',') || ' h de sommeil');
    end if;
  end if;

  if f <> '' then
    patch := patch || jsonb_build_object('flow',
      case
        when f like '%aucun%' or f like '%none%' then null
        when f like '%spot%' then 'spotting'
        when f like '%l_ger%' or f like '%light%' or f like '%faible%' then 'leger'
        when f like '%abond%' or f like '%heavy%' or f like '%fort%' then 'abondant'
        else 'moyen'
      end);
    src := src || '{"flow":"sante"}';
    msg := msg || (case when f like '%aucun%' or f like '%none%' then 'pas de règles' else 'règles' end)::text;
  end if;

  if patch = '{}'::jsonb then return 'Rien à enregistrer'; end if;

  insert into public.vie_days (user_id, day, data)
  values (uid, d, patch || jsonb_build_object('src', src))
  on conflict (user_id, day) do update
    set data = public.vie_days.data || patch
             || jsonb_build_object('src', coalesce(public.vie_days.data -> 'src', '{}'::jsonb) || src),
        updated_at = now();

  return 'Enregistré pour le ' || to_char(d, 'DD/MM') || ' : ' || array_to_string(msg, ', ');
end;
$$;
revoke all on function public.vie_import(text, date, numeric, numeric, text) from public;
grant execute on function public.vie_import(text, date, numeric, numeric, text) to anon, authenticated;

-- Mise à jour en direct dans l'app quand le raccourci envoie des données
do $$ begin
  alter publication supabase_realtime add table public.vie_days;
exception when duplicate_object then null; end $$;
