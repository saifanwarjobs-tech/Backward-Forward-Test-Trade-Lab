-- BFT pricing v4. Run in Supabase SQL Editor AFTER schema.sql. Safe to re-run.
-- Gives you: per-product prices (tools, bundle, Academy), per-item prices (PDF / course / indicator),
-- free trial minutes + free journal entries, monthly or one-time plans, and an access list (entitlements).

create table if not exists products(
  id text primary key,                 -- journal | lab | classroom | all_tools | academy | anything you add
  kind text not null default 'tool',
  name text not null,
  price_once int,                      -- rupees, NULL = not sold one-time
  price_month int,                     -- rupees per 30 days, NULL = no monthly plan
  trial_minutes int,                   -- free minutes per browser, NULL = unlimited free
  free_entries int,                    -- free journal entries, NULL = unlimited free
  active boolean default true, sort int default 0, updated_at timestamptz default now());
alter table products enable row level security;
drop policy if exists pr_read on products;  create policy pr_read on products for select using(active or is_admin());
drop policy if exists pr_admin on products; create policy pr_admin on products for all using(is_admin()) with check(is_admin());
grant select on products to anon, authenticated;
grant insert, update, delete on products to authenticated;

-- PLACEHOLDER prices: change them in admin-pricing.html
insert into products(id,kind,name,price_once,price_month,trial_minutes,free_entries,sort) values
 ('journal','tool','Premium Journal',999,199,60,10,1),
 ('lab','tool','Testing Lab',1499,299,60,null,2),
 ('classroom','tool','Classroom',999,199,60,null,3),
 ('all_tools','tool','All tools bundle',2499,399,null,null,4),
 ('academy','academy','BFT Academy (everything)',4999,null,null,null,5)
on conflict (id) do nothing;

-- price of one PDF / course / indicator (rupees). NULL = only through Academy
alter table items add column if not exists price int;

create table if not exists entitlements(
  email text not null, product_id text not null,   -- product id, or 'item:<items.id>'
  plan text not null check(plan in('once','month','manual')),
  expires_at timestamptz,                           -- NULL = lifetime
  amount int, phone text, created_at timestamptz default now(),
  primary key(email, product_id));
alter table entitlements enable row level security;
drop policy if exists ent_me on entitlements;    create policy ent_me on entitlements for select using(email = lower(auth.jwt()->>'email'));
drop policy if exists ent_admin on entitlements; create policy ent_admin on entitlements for all using(is_admin()) with check(is_admin());
grant select on entitlements to authenticated;
grant insert, update, delete on entitlements to authenticated;

alter table payments add column if not exists product_id text;
alter table payments add column if not exists plan text;
alter table payments add column if not exists source text default 'razorpay';
create index if not exists payments_phone_idx on payments(phone);
create index if not exists payments_email_idx on payments(email);

create or replace function has_product(pid text) returns boolean language sql security definer stable set search_path = public as
$$select exists(select 1 from entitlements e where e.email = lower(auth.jwt()->>'email') and e.product_id = pid
                  and (e.expires_at is null or e.expires_at > now()))
   and exists(select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null)$$;

-- Paid secrets: Academy student OR bought that single item
drop policy if exists s_read on item_secrets;
create policy s_read on item_secrets for select using(is_admin() or exists(
  select 1 from items i where i.id = item_id and i.published and (i.free or is_student() or has_product('item:'||i.id::text))));
drop policy if exists ls_read on lesson_secrets;
create policy ls_read on lesson_secrets for select using(is_admin() or exists(
  select 1 from lessons l join items i on i.id = l.item_id
  where l.id = lesson_id and i.published and (i.free or l.free or is_student() or has_product('item:'||i.id::text))));
drop policy if exists st_pdf_read on storage.objects;
create policy st_pdf_read on storage.objects for select using(bucket_id = 'academy-pdfs' and (
  is_student() or exists(select 1 from item_secrets s join items i on i.id = s.item_id
    where s.pdf_path = name and i.published and (i.free or has_product('item:'||i.id::text)))));
drop policy if exists st_video_read on storage.objects;
create policy st_video_read on storage.objects for select using(bucket_id = 'academy-videos' and (
  is_student() or exists(select 1 from lesson_secrets s join lessons l on l.id = s.lesson_id join items i on i.id = l.item_id
    where s.video_path = name and i.published and (i.free or l.free or has_product('item:'||i.id::text)))));
