-- ═══════════════════════════════════════════════════════════════════════
--  SACS U16 B Hockey — Season Tracker
--  ONE-TIME DATABASE SETUP
--
--  Where:  supabase.com  →  your project  →  SQL Editor  →  New query
--  Do:     paste this whole file, press Run.  You only ever do this once.
--
--  What it does: creates a single table holding the app's entire state as
--  one JSON row, and allows the app's public key to read and write it.
--  It does NOT touch anything you already had — the new table is called
--  u16b_state, so your old table (if any) is left completely alone.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.u16b_state (
  id         integer primary key,
  data       jsonb   not null,
  rev        bigint  not null default 1,
  updated_at timestamptz not null default now()
);

-- keep updated_at honest
create or replace function public.u16b_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists u16b_touch_trg on public.u16b_state;
create trigger u16b_touch_trg
  before update on public.u16b_state
  for each row execute function public.u16b_touch();

-- ── access ──────────────────────────────────────────────────────────────
-- The app ships with a public (anon) key, so anyone with the site URL can
-- read and write this one row. That is the intended behaviour: the coach
-- and manager share the link and both edit. There is nothing sensitive
-- here beyond player names and points.
alter table public.u16b_state enable row level security;

drop policy if exists u16b_read  on public.u16b_state;
drop policy if exists u16b_write on public.u16b_state;
drop policy if exists u16b_edit  on public.u16b_state;

create policy u16b_read  on public.u16b_state for select using (true);
create policy u16b_write on public.u16b_state for insert with check (true);
create policy u16b_edit  on public.u16b_state for update using (true) with check (true);

grant usage  on schema public to anon;
grant select, insert, update on public.u16b_state to anon;

-- ── done ────────────────────────────────────────────────────────────────
-- Leave the table empty. The first time someone opens the site it seeds
-- itself with the full 2026 season imported from your Google Sheet.
--
-- Sanity check — should return 0 rows the first time, 1 row after that:
select id, rev, updated_at, jsonb_array_length(data->'players') as players
from public.u16b_state;
