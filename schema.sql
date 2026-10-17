-- Run once in Supabase > SQL Editor. Then: insert into admins values ('you@email.com');
create table admins(email text primary key);
create table students(email text primary key, note text, created_at timestamptz default now());
create table items(id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in('course','pdf','indicator')), title text not null, descr text,
 free boolean default false, published boolean default false, sort int default 0, created_at timestamptz default now());
create table item_secrets(item_id uuid primary key references items on delete cascade, video_url text, pdf_path text, code text);

create function is_admin() returns boolean language sql security definer stable as
$$select exists(select 1 from admins where email=lower(auth.jwt()->>'email'))$$;
create function is_student() returns boolean language sql security definer stable as
$$select exists(select 1 from students where email=lower(auth.jwt()->>'email'))$$;

alter table admins enable row level security; alter table students enable row level security;
alter table items enable row level security; alter table item_secrets enable row level security;

create policy a_admins on admins for select using(is_admin());
create policy a_students_all on students for all using(is_admin()) with check(is_admin());
create policy a_students_me on students for select using(email=lower(auth.jwt()->>'email'));
create policy i_read on items for select using(published or is_admin());
create policy i_admin on items for all using(is_admin()) with check(is_admin());
create policy s_read on item_secrets for select using(is_admin() or exists(
 select 1 from items i where i.id=item_id and i.published and (i.free or is_student())));
create policy s_admin on item_secrets for all using(is_admin()) with check(is_admin());

insert into storage.buckets(id,name,public) values('academy-pdfs','academy-pdfs',false) on conflict do nothing;
create policy p_admin on storage.objects for all using(bucket_id='academy-pdfs' and is_admin()) with check(bucket_id='academy-pdfs' and is_admin());
create policy p_read on storage.objects for select using(bucket_id='academy-pdfs' and is_student());
