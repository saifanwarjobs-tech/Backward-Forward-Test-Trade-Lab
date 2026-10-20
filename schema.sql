-- BFT Academy: database schema v2.  SAFE TO RE-RUN (idempotent).
-- Run in Supabase > SQL Editor.  First time only, also run:
--   insert into admins values ('you@email.com');
--
-- What v2 adds over v1:
--   * lessons + lesson_secrets  (real courses: modules, lessons, durations, per-lesson free preview)
--   * private video bucket (academy-videos) and public cover bucket (academy-thumbs)
--   * extra columns on items (category, level, cover, timeframe, market, pages, delivery)
--   * students: phone, amount paid, expiry date
--   * FIX: free PDFs/videos can now be opened by people who have not paid
--   * FIX: access requires a CONFIRMED email (and not expired); admin check also needs a confirmed email
--   * FIX: security-definer functions pin search_path
--
-- Also in Supabase dashboard: Authentication > Providers > Email > turn ON "Confirm email".

create table if not exists admins(email text primary key);
create table if not exists students(email text primary key, note text, created_at timestamptz default now());
create table if not exists items(
  id uuid primary key default gen_random_uuid(),
  kind text not null check(kind in('course','pdf','indicator')),
  title text not null, descr text,
  free boolean default false, published boolean default false, sort int default 0,
  created_at timestamptz default now());
create table if not exists item_secrets(
  item_id uuid primary key references items on delete cascade,
  video_url text, pdf_path text, code text);

-- v2 columns
alter table students add column if not exists phone text;
alter table students add column if not exists amount int;
alter table students add column if not exists expires_at timestamptz;
alter table items add column if not exists category text;
alter table items add column if not exists level text;
alter table items add column if not exists thumb_path text;
alter table items add column if not exists tf text;
alter table items add column if not exists mk text;
alter table items add column if not exists pages int;
alter table items add column if not exists delivery text default 'code';

update students set email = lower(email) where email <> lower(email);

create table if not exists lessons(
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references items on delete cascade,
  module text default 'Lessons',
  title text not null,
  duration text,
  free boolean default false,
  lab text,
  sort int default 0,
  created_at timestamptz default now());
create index if not exists lessons_item_idx on lessons(item_id, sort);

create table if not exists lesson_secrets(
  lesson_id uuid primary key references lessons on delete cascade,
  video_url text,      -- YouTube / Vimeo / Bunny / any https embed or .mp4 link
  video_path text);    -- file uploaded to the private academy-videos bucket

-- helper functions
create or replace function is_admin() returns boolean language sql security definer stable set search_path = public as
$$select exists(select 1 from admins a where a.email = lower(auth.jwt()->>'email'))
   and exists(select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null)$$;

create or replace function is_student() returns boolean language sql security definer stable set search_path = public as
$$select exists(select 1 from students s where s.email = lower(auth.jwt()->>'email')
                  and (s.expires_at is null or s.expires_at > now()))
   and exists(select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null)$$;

alter table admins enable row level security;
alter table students enable row level security;
alter table items enable row level security;
alter table item_secrets enable row level security;
alter table lessons enable row level security;
alter table lesson_secrets enable row level security;

-- policies (dropped first so this file can be re-run)
drop policy if exists a_admins on admins;
create policy a_admins on admins for select using(is_admin());

drop policy if exists a_students_all on students;
create policy a_students_all on students for all using(is_admin()) with check(is_admin());
drop policy if exists a_students_me on students;
create policy a_students_me on students for select using(email = lower(auth.jwt()->>'email'));

drop policy if exists i_read on items;
create policy i_read on items for select using(published or is_admin());
drop policy if exists i_admin on items;
create policy i_admin on items for all using(is_admin()) with check(is_admin());

drop policy if exists s_read on item_secrets;
create policy s_read on item_secrets for select using(is_admin() or exists(
  select 1 from items i where i.id = item_id and i.published and (i.free or is_student())));
drop policy if exists s_admin on item_secrets;
create policy s_admin on item_secrets for all using(is_admin()) with check(is_admin());

drop policy if exists l_read on lessons;
create policy l_read on lessons for select using(is_admin() or exists(
  select 1 from items i where i.id = item_id and i.published));
drop policy if exists l_admin on lessons;
create policy l_admin on lessons for all using(is_admin()) with check(is_admin());

drop policy if exists ls_read on lesson_secrets;
create policy ls_read on lesson_secrets for select using(is_admin() or exists(
  select 1 from lessons l join items i on i.id = l.item_id
  where l.id = lesson_id and i.published and (i.free or l.free or is_student())));
drop policy if exists ls_admin on lesson_secrets;
create policy ls_admin on lesson_secrets for all using(is_admin()) with check(is_admin());

-- storage buckets
insert into storage.buckets(id, name, public) values
  ('academy-pdfs', 'academy-pdfs', false),
  ('academy-videos', 'academy-videos', false),
  ('academy-thumbs', 'academy-thumbs', true)
on conflict (id) do nothing;
-- NOTE: Supabase free plan caps every upload at 50 MB (Storage settings). For longer videos
-- upgrade the plan or paste an unlisted YouTube / Vimeo / Bunny link in the admin instead.

drop policy if exists p_admin on storage.objects;
drop policy if exists p_read on storage.objects;
drop policy if exists st_admin on storage.objects;
create policy st_admin on storage.objects for all
  using(bucket_id in ('academy-pdfs','academy-videos','academy-thumbs') and is_admin())
  with check(bucket_id in ('academy-pdfs','academy-videos','academy-thumbs') and is_admin());

drop policy if exists st_pdf_read on storage.objects;
create policy st_pdf_read on storage.objects for select using(bucket_id = 'academy-pdfs' and (
  is_student() or exists(select 1 from item_secrets s join items i on i.id = s.item_id
                         where s.pdf_path = name and i.published and i.free)));

drop policy if exists st_video_read on storage.objects;
create policy st_video_read on storage.objects for select using(bucket_id = 'academy-videos' and (
  is_student() or exists(select 1 from lesson_secrets s join lessons l on l.id = s.lesson_id
                         join items i on i.id = l.item_id
                         where s.video_path = name and i.published and (i.free or l.free))));

-- one-time data migration from v1 (runs only while lessons is still empty)
do $$
begin
  if not exists(select 1 from lessons) then
    insert into lessons(item_id, module, title, free, sort)
      select i.id, 'Lessons', i.title, false, 0 from items i where i.kind = 'course';
    insert into lesson_secrets(lesson_id, video_url)
      select l.id, s.video_url from lessons l join item_secrets s on s.item_id = l.item_id
      where coalesce(s.video_url, '') <> '';
    update items set delivery = 'invite' where kind = 'indicator'
      and not exists(select 1 from item_secrets s where s.item_id = items.id and coalesce(s.code, '') <> '');
  end if;
end $$;

-- Journal cloud backup (optional, per user). Safe to re-run.
create table if not exists journal_cloud(
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null,
  updated_at timestamptz default now());
alter table journal_cloud enable row level security;
drop policy if exists journal_cloud_sel on journal_cloud;
drop policy if exists journal_cloud_ins on journal_cloud;
drop policy if exists journal_cloud_upd on journal_cloud;
drop policy if exists journal_cloud_del on journal_cloud;
create policy journal_cloud_sel on journal_cloud for select to authenticated using (auth.uid() = user_id);
create policy journal_cloud_ins on journal_cloud for insert to authenticated with check (auth.uid() = user_id);
create policy journal_cloud_upd on journal_cloud for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy journal_cloud_del on journal_cloud for delete to authenticated using (auth.uid() = user_id);
grant select, insert, update, delete on journal_cloud to authenticated;

-- Site settings (price, YouTube, instructor, reviews, contact). One row, editable from admin.html > Settings.
-- Anyone can read it (it is shown on the public Academy page); only admins can change it.
create table if not exists site_settings(
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now());
alter table site_settings enable row level security;
drop policy if exists ss_read on site_settings;
drop policy if exists ss_admin on site_settings;
create policy ss_read on site_settings for select using(true);
create policy ss_admin on site_settings for all using(is_admin()) with check(is_admin());
grant select on site_settings to anon, authenticated;
grant insert, update on site_settings to authenticated;
insert into site_settings(id, data) values (1, '{}'::jsonb) on conflict (id) do nothing;

-- Student progress (per user, synced across devices). Safe to re-run.
-- A student can only read and write their own rows. Admins see totals through the two functions below,
-- never the students' private notes.
create table if not exists lesson_progress(
  user_id uuid not null references auth.users on delete cascade,
  lesson_id uuid not null references lessons on delete cascade,
  email text default lower(coalesce(auth.jwt()->>'email','')),
  done boolean not null default false,
  note text,
  updated_at timestamptz default now(),
  primary key (user_id, lesson_id));
create index if not exists lesson_progress_lesson_idx on lesson_progress(lesson_id);

create table if not exists member_state(
  user_id uuid primary key references auth.users on delete cascade,
  email text default lower(coalesce(auth.jwt()->>'email','')),
  last_lesson uuid references lessons on delete set null,
  last_seen timestamptz default now());

alter table lesson_progress enable row level security;
alter table member_state enable row level security;
drop policy if exists lp_sel on lesson_progress;
drop policy if exists lp_ins on lesson_progress;
drop policy if exists lp_upd on lesson_progress;
drop policy if exists lp_del on lesson_progress;
create policy lp_sel on lesson_progress for select to authenticated using (user_id = auth.uid());
create policy lp_ins on lesson_progress for insert to authenticated with check (user_id = auth.uid());
create policy lp_upd on lesson_progress for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy lp_del on lesson_progress for delete to authenticated using (user_id = auth.uid());
drop policy if exists ms_sel on member_state;
drop policy if exists ms_ins on member_state;
drop policy if exists ms_upd on member_state;
create policy ms_sel on member_state for select to authenticated using (user_id = auth.uid());
create policy ms_ins on member_state for insert to authenticated with check (user_id = auth.uid());
create policy ms_upd on member_state for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
grant select, insert, update, delete on lesson_progress to authenticated;
grant select, insert, update on member_state to authenticated;

create or replace function admin_student_progress()
returns table(stu_email text, lessons_done int, last_seen timestamptz, last_lesson uuid)
language sql security definer stable set search_path = public as
$$select m.email, coalesce(d.n, 0)::int, m.last_seen, m.last_lesson
  from member_state m
  left join (select p.user_id, count(*) filter (where p.done) as n from lesson_progress p group by p.user_id) d
    on d.user_id = m.user_id
  where is_admin()$$;

create or replace function admin_lesson_progress()
returns table(lesson_id uuid, done_count int)
language sql security definer stable set search_path = public as
$$select p.lesson_id, count(*) filter (where p.done)::int
  from lesson_progress p
  where is_admin()
  group by p.lesson_id$$;

revoke all on function admin_student_progress() from public, anon;
revoke all on function admin_lesson_progress() from public, anon;
grant execute on function admin_student_progress() to authenticated;
grant execute on function admin_lesson_progress() to authenticated;


-- ===== Razorpay payments (v3). Written only by the server-side webhook (service role), readable by admin =====
create table if not exists payments(
  payment_id text primary key,            -- Razorpay payment id (unique => webhook retries are harmless)
  order_id text, email text not null, phone text,
  amount int,                              -- in rupees
  status text, created_at timestamptz default now());
alter table payments enable row level security;
drop policy if exists a_payments_all on payments;
create policy a_payments_all on payments for all using(is_admin()) with check(is_admin());


-- ===== Website analytics (v1). Same block as analytics.sql, kept here so a full re-run of schema.sql includes it =====
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
