-- ======================================================================
-- BFT Trade Lab: analytics spam limit.  SAFE TO RE-RUN.
-- Run once in Supabase > SQL Editor (after analytics.sql).
-- What it does
--   * one visitor_id can add at most 60 rows per minute to web_views / web_events
--   * the whole table accepts at most 1500 new rows per minute
-- A blocked insert simply fails; the site keeps working (analytics is fire-and-forget).
-- Honest limit: someone who keeps inventing new visitor_ids is stopped only by the global
-- cap, which protects your free storage but can pause analytics while an attack lasts.
-- To undo:  drop trigger web_views_rl on web_views;  drop trigger web_events_rl on web_events;
-- ======================================================================
create index if not exists web_views_visitor_idx  on web_views (visitor_id, created_at desc);
create index if not exists web_events_visitor_idx on web_events (visitor_id, created_at desc);

create or replace function analytics_rate_limit() returns trigger
language plpgsql security definer set search_path = public as $$
declare per_visitor int; global_n int;
begin
  execute format('select count(*) from %I where visitor_id = $1 and created_at > now() - interval ''1 minute''', tg_table_name)
    into per_visitor using new.visitor_id;
  if per_visitor >= 60 then raise exception 'rate limit' using errcode = '54000'; end if;
  execute format('select count(*) from %I where created_at > now() - interval ''1 minute''', tg_table_name)
    into global_n;
  if global_n >= 1500 then raise exception 'rate limit' using errcode = '54000'; end if;
  return new;
end $$;
revoke all on function analytics_rate_limit() from public, anon, authenticated;

drop trigger if exists web_views_rl on web_views;
create trigger web_views_rl  before insert on web_views  for each row execute function analytics_rate_limit();
drop trigger if exists web_events_rl on web_events;
create trigger web_events_rl before insert on web_events for each row execute function analytics_rate_limit();
