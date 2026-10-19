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
