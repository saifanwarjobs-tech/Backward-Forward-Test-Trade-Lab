-- ======================================================================
-- BFT Trade Lab: Website Analytics (v1).  SAFE TO RE-RUN (idempotent).
-- Run once in Supabase > SQL Editor (needs schema.sql already run: it uses is_admin()).
--
-- What it creates
--   web_views   one row per page view (source, device, city, time on page, scroll depth)
--   web_events  one row per action (button / WhatsApp / call / outbound / search / form)
--   track_ping()            visitors' browsers top up time-on-page + scroll for their OWN page view
--   admin_analytics()       one call that returns every number the admin Analytics tab shows
--   admin_purge_analytics() delete old rows from the admin Analytics tab
--
-- Security
--   * Visitors (anon) can only INSERT, with length limits, and cannot read anything back.
--   * Only admins (is_admin()) can read or delete.
--   * No IP address, name, email or phone is ever stored.
-- ======================================================================

create table if not exists web_views(
  id uuid primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  visitor_id text not null, session_id text not null,
  page text not null, title text,
  referrer text, source text, channel text, medium text, campaign text,
  device text, os text, browser text, screen text, language text, tz text,
  country text, country_code text, region text, city text,
  landing boolean default false, page_index int default 1,
  visit_count int default 1, is_new boolean default true,
  duration_sec int not null default 0, max_scroll int not null default 0, interactions int not null default 0);
create index if not exists web_views_created_idx on web_views(created_at desc);
create index if not exists web_views_session_idx on web_views(session_id);

create table if not exists web_events(
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  type text not null, label text, target text, page text,
  visitor_id text not null, session_id text not null);
create index if not exists web_events_created_idx on web_events(created_at desc);

alter table web_views enable row level security;
alter table web_events enable row level security;

revoke all on web_views, web_events from anon, authenticated;
grant insert on web_views, web_events to anon, authenticated;
grant select, delete on web_views, web_events to authenticated;

drop policy if exists wv_ins on web_views;
create policy wv_ins on web_views for insert to anon, authenticated with check (
  created_at = now() and updated_at is null
  and duration_sec = 0 and max_scroll = 0 and interactions = 0
  and char_length(visitor_id) between 8 and 80 and char_length(session_id) between 8 and 80
  and char_length(page) between 1 and 160 and char_length(coalesce(title, '')) <= 160
  and char_length(coalesce(referrer, '')) <= 120 and char_length(coalesce(source, '')) <= 60
  and char_length(coalesce(channel, '')) <= 40 and char_length(coalesce(medium, '')) <= 40
  and char_length(coalesce(campaign, '')) <= 80 and char_length(coalesce(device, '')) <= 20
  and char_length(coalesce(os, '')) <= 20 and char_length(coalesce(browser, '')) <= 30
  and char_length(coalesce(screen, '')) <= 20 and char_length(coalesce(language, '')) <= 20
  and char_length(coalesce(tz, '')) <= 60 and char_length(coalesce(country, '')) <= 60
  and char_length(coalesce(country_code, '')) <= 4 and char_length(coalesce(region, '')) <= 60
  and char_length(coalesce(city, '')) <= 60
  and coalesce(page_index, 1) between 0 and 10000 and coalesce(visit_count, 1) between 0 and 100000);

drop policy if exists we_ins on web_events;
create policy we_ins on web_events for insert to anon, authenticated with check (
  created_at = now()
  and type in ('cta_click','button_click','whatsapp_click','call_click','telegram_click','email_click',
               'outbound_click','download_click','search','form_start','form_submit','custom')
  and char_length(coalesce(label, '')) <= 80 and char_length(coalesce(target, '')) <= 80
  and char_length(coalesce(page, '')) <= 160
  and char_length(visitor_id) between 8 and 80 and char_length(session_id) between 8 and 80);

drop policy if exists wv_admin on web_views;
create policy wv_admin on web_views for select to authenticated using (is_admin());
drop policy if exists wv_admin_del on web_views;
create policy wv_admin_del on web_views for delete to authenticated using (is_admin());
drop policy if exists we_admin on web_events;
create policy we_admin on web_events for select to authenticated using (is_admin());
drop policy if exists we_admin_del on web_events;
create policy we_admin_del on web_events for delete to authenticated using (is_admin());

-- A visitor's browser may only top up the engagement fields of the page view it just created
-- (it must know the random id). Values are clamped; rows older than 1 day are ignored.
create or replace function track_ping(p_id uuid, p_duration int default null, p_scroll int default null,
  p_interactions int default null, p_title text default null, p_country text default null,
  p_country_code text default null, p_region text default null, p_city text default null)
returns void language sql security definer volatile set search_path = public as
$$update web_views set
    duration_sec = greatest(duration_sec, least(coalesce(p_duration, 0), 14400)),
    max_scroll = greatest(max_scroll, least(greatest(coalesce(p_scroll, 0), 0), 100)),
    interactions = greatest(interactions, least(greatest(coalesce(p_interactions, 0), 0), 100000)),
    title = coalesce(left(p_title, 160), title),
    country = case when coalesce(country, '') = '' then left(p_country, 60) else country end,
    country_code = case when coalesce(country_code, '') = '' then left(p_country_code, 4) else country_code end,
    region = case when coalesce(region, '') = '' then left(p_region, 60) else region end,
    city = case when coalesce(city, '') = '' then left(p_city, 60) else city end,
    updated_at = now()
  where id = p_id and created_at > now() - interval '1 day'$$;
revoke all on function track_ping(uuid, int, int, int, text, text, text, text, text) from public;
grant execute on function track_ping(uuid, int, int, int, text, text, text, text, text) to anon, authenticated;

-- ---- numbers for one period (internal helper, not callable from the browser) ----
create or replace function _an_totals(p_from timestamptz, p_to timestamptz)
returns jsonb language sql stable set search_path = public as
$$select jsonb_build_object(
    'views', (select count(*) from web_views where created_at >= p_from and created_at < p_to),
    'visitors', (select count(distinct visitor_id) from web_views where created_at >= p_from and created_at < p_to),
    'sessions', (select count(distinct session_id) from web_views where created_at >= p_from and created_at < p_to),
    'new_visitors', (select count(distinct visitor_id) from web_views where created_at >= p_from and created_at < p_to and is_new),
    'avg_sec', (select coalesce(round(avg(duration_sec) filter (where duration_sec > 0)), 0) from web_views where created_at >= p_from and created_at < p_to),
    'bounce_pct', (select coalesce(round(100.0 * count(*) filter (where n = 1 and mx < 10) / nullif(count(*), 0)), 0)
                   from (select session_id, count(*) n, max(duration_sec) mx from web_views
                         where created_at >= p_from and created_at < p_to group by 1) s),
    'events', (select count(*) from web_events where created_at >= p_from and created_at < p_to))$$;
revoke all on function _an_totals(timestamptz, timestamptz) from public, anon, authenticated;

-- ---- everything the admin Analytics tab shows, in one call ----
create or replace function admin_analytics(p_from timestamptz, p_to timestamptz)
returns jsonb language plpgsql security definer stable set search_path = public as
$$
declare
  len interval;
  res jsonb;
begin
  if not is_admin() then raise exception 'not admin'; end if;
  if p_to <= p_from then raise exception 'bad range'; end if;
  if p_to - p_from > interval '400 days' then raise exception 'range too long'; end if;
  len := p_to - p_from;

  with
  v as (select * from web_views where created_at >= p_from and created_at < p_to),
  ev as (select * from web_events where created_at >= p_from and created_at < p_to),
  sess as (select distinct on (session_id) session_id, city, country, source, device from v order by session_id, created_at desc),
  daily as (
    select to_char(g.d, 'YYYY-MM-DD') d, coalesce(c.views, 0) views, coalesce(c.visitors, 0) visitors, coalesce(c.sessions, 0) sessions
    from generate_series((p_from at time zone 'Asia/Kolkata')::date::timestamp,
                         ((p_to - interval '1 second') at time zone 'Asia/Kolkata')::date::timestamp, interval '1 day') g(d)
    left join (select (created_at at time zone 'Asia/Kolkata')::date dd, count(*) views,
                      count(distinct visitor_id) visitors, count(distinct session_id) sessions
               from v group by 1) c on c.dd = g.d::date
    order by g.d),
  recent as (
    select * from (
      select created_at at_, 'view' kind, page what, coalesce(title, '') label, city, country, source, device from v
      union all
      select e.created_at, 'event', e.type, coalesce(e.label, ''), s.city, s.country, s.source, s.device
      from ev e left join sess s on s.session_id = e.session_id) u
    order by at_ desc limit 40)
  select jsonb_build_object(
    'range', jsonb_build_object('from', p_from, 'to', p_to),
    'cur', _an_totals(p_from, p_to),
    'prev', _an_totals(p_from - len, p_from),
    'ret', (select jsonb_build_object('new', count(*) filter (where nw), 'returning', count(*) filter (where not nw))
            from (select visitor_id, bool_or(is_new) nw from v group by 1) x),
    'live', (select count(distinct visitor_id) from (
               select visitor_id from web_views where coalesce(updated_at, created_at) > now() - interval '5 minutes'
               union all select visitor_id from web_events where created_at > now() - interval '5 minutes') l),
    'daily', (select coalesce(jsonb_agg(to_jsonb(daily) order by d), '[]') from daily),
    'hours', (select coalesce(jsonb_agg(jsonb_build_object('h', h, 'n', n) order by h), '[]') from (
                select extract(hour from created_at at time zone 'Asia/Kolkata')::int h, count(*) n from v group by 1) x),
    'pages', (select coalesce(jsonb_agg(x), '[]') from (
                select page, count(*) views, count(distinct visitor_id) visitors,
                       coalesce(round(avg(duration_sec) filter (where duration_sec > 0)), 0) avg_sec,
                       coalesce(round(avg(max_scroll) filter (where duration_sec > 0)), 0) avg_scroll
                from v group by page order by count(*) desc limit 20) x),
    'entries', (select coalesce(jsonb_agg(x), '[]') from (
                select page, count(*) n from v where landing group by page order by count(*) desc limit 10) x),
    'sources', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(source, ''), 'Direct') source, coalesce(nullif(channel, ''), 'Direct') channel,
                       count(distinct session_id) sessions, count(distinct visitor_id) visitors
                from v group by 1, 2 order by count(distinct session_id) desc limit 15) x),
    'channels', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(channel, ''), 'Direct') name, count(distinct session_id) n from v group by 1 order by 2 desc) x),
    'campaigns', (select coalesce(jsonb_agg(x), '[]') from (
                select campaign name, count(distinct session_id) n from v where coalesce(campaign, '') <> '' group by 1 order by 2 desc limit 10) x),
    'countries', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(country, ''), 'Unknown') name, count(distinct visitor_id) n from v group by 1 order by 2 desc limit 12) x),
    'regions', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(region, ''), 'Unknown') name, count(distinct visitor_id) n from v group by 1 order by 2 desc limit 12) x),
    'cities', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(city, ''), 'Unknown') name, count(distinct visitor_id) n from v group by 1 order by 2 desc limit 15) x),
    'devices', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(device, ''), 'Unknown') name, count(distinct visitor_id) n from v group by 1 order by 2 desc) x),
    'oses', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(os, ''), 'Unknown') name, count(distinct visitor_id) n from v group by 1 order by 2 desc limit 8) x),
    'browsers', (select coalesce(jsonb_agg(x), '[]') from (
                select coalesce(nullif(browser, ''), 'Unknown') name, count(distinct visitor_id) n from v group by 1 order by 2 desc limit 8) x),
    'event_types', (select coalesce(jsonb_agg(x), '[]') from (
                select type, count(*) n, count(distinct visitor_id) visitors from ev group by 1 order by 2 desc) x),
    'event_top', (select coalesce(jsonb_agg(x), '[]') from (
                select type, label, n from (
                  select type, coalesce(nullif(label, ''), '(no label)') label, count(*) n,
                         row_number() over (partition by type order by count(*) desc) rn
                  from ev group by 1, 2) t where rn <= 8 order by type, n desc) x),
    'recent', (select coalesce(jsonb_agg(to_jsonb(recent) order by at_ desc), '[]') from recent)
  ) into res;
  return res;
end
$$;
revoke all on function admin_analytics(timestamptz, timestamptz) from public, anon;
grant execute on function admin_analytics(timestamptz, timestamptz) to authenticated;

-- ---- delete old analytics rows (admin only). Returns how many rows were removed. ----
create or replace function admin_purge_analytics(p_days int)
returns int language plpgsql security definer volatile set search_path = public as
$$
declare a int; b int;
begin
  if not is_admin() then raise exception 'not admin'; end if;
  if p_days is null or p_days < 0 then raise exception 'bad days'; end if;
  delete from web_views where created_at < now() - make_interval(days => p_days);
  get diagnostics a = row_count;
  delete from web_events where created_at < now() - make_interval(days => p_days);
  get diagnostics b = row_count;
  return a + b;
end
$$;
revoke all on function admin_purge_analytics(int) from public, anon;
grant execute on function admin_purge_analytics(int) to authenticated;
