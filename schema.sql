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
