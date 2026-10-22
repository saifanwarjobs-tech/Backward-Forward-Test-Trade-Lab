-- BFT Trade Lab: honest Forward Test (server-side lock + server-held holdout data)
-- Run once in Supabase > SQL Editor, AFTER schema.sql and schema_pricing.sql. Safe to re-run.
--
-- What this enforces on the server (not in the browser):
--  1. A user's rules are saved with the SERVER clock and can never be edited or deleted.
--     Every lock is a new numbered attempt, so "I tried 7 versions on the same data" is visible.
--  2. The holdout candles (the reserved period) are NOT in the public price files. They sit in
--     the private storage bucket 'holdout' and are released only to a signed-in user who has
--     locked rules for that dataset AND (owns the Lab or the dataset is on the free list).
--
-- What it does NOT do: it does not audit the trades. Trading in the Lab is manual, so the
-- server proves "these rules existed before the holdout was seen", not "these trades followed them".

create table if not exists fw_free(            -- datasets anyone with an account may forward-test for free
  dataset text primary key check (dataset ~ '^[a-z0-9-]{3,60}$'));
insert into fw_free(dataset) values ('xauusd-d1-data') on conflict do nothing;   -- a free taste; edit as you like
alter table fw_free enable row level security;
drop policy if exists fwf_read on fw_free;  create policy fwf_read on fw_free for select using(true);
drop policy if exists fwf_admin on fw_free; create policy fwf_admin on fw_free for all using(is_admin()) with check(is_admin());
grant select on fw_free to anon, authenticated;
grant insert, update, delete on fw_free to authenticated;

create table if not exists fw_locks(
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  dataset text not null check (dataset ~ '^[a-z0-9-]{3,60}$'),
  attempt int not null,
  rules text not null check (length(rules) between 10 and 4000),
  locked_at timestamptz not null default now(),
  unique (user_id, dataset, attempt));
create index if not exists fw_locks_user_idx on fw_locks(user_id, dataset, attempt desc);
alter table fw_locks enable row level security;
drop policy if exists fwl_me on fw_locks;    create policy fwl_me on fw_locks for select using(user_id = auth.uid());
drop policy if exists fwl_admin on fw_locks; create policy fwl_admin on fw_locks for select using(is_admin());
-- no insert / update / delete policy and no grant: the only way in is fw_lock() below
revoke all on fw_locks from anon, authenticated;
grant select on fw_locks to authenticated;

create or replace function fw_can_holdout(ds text) returns boolean
language sql security definer stable set search_path = public as
$$select auth.uid() is not null
    and (has_product('lab') or has_product('all_tools') or exists(select 1 from fw_free f where f.dataset = ds))$$;
revoke all on function fw_can_holdout(text) from public;
grant execute on function fw_can_holdout(text) to authenticated;

create or replace function fw_lock(ds text, rules_txt text) returns fw_locks
language plpgsql security definer set search_path = public as
$$declare n int; r fw_locks; t text := btrim(coalesce(rules_txt, ''));
begin
  if auth.uid() is null then raise exception 'login_required'; end if;
  if ds is null or ds !~ '^[a-z0-9-]{3,60}$' then raise exception 'bad_dataset'; end if;
  if length(t) < 10 or length(t) > 4000 then raise exception 'bad_rules'; end if;
  if not fw_can_holdout(ds) then raise exception 'not_entitled'; end if;
  if (select count(*) from fw_locks where user_id = auth.uid() and locked_at > now() - interval '1 day') >= 30 then
    raise exception 'too_many_locks'; end if;
  select coalesce(max(attempt), 0) + 1 into n from fw_locks where user_id = auth.uid() and dataset = ds;
  insert into fw_locks(user_id, dataset, attempt, rules) values (auth.uid(), ds, n, t) returning * into r;
  return r;
end$$;
revoke all on function fw_lock(text, text) from public;
grant execute on function fw_lock(text, text) to authenticated;

-- private bucket for the holdout candles (upload holdout/*.csv.gz here, see FORWARD_SETUP.md)
insert into storage.buckets(id, name, public) values ('holdout', 'holdout', false) on conflict (id) do update set public = false;
drop policy if exists st_holdout_read on storage.objects;
create policy st_holdout_read on storage.objects for select using(bucket_id = 'holdout' and (
  is_admin() or (
    fw_can_holdout(split_part(name, '.', 1))
    and exists(select 1 from fw_locks l where l.user_id = auth.uid() and l.dataset = split_part(name, '.', 1)))));
drop policy if exists st_holdout_admin on storage.objects;
create policy st_holdout_admin on storage.objects for all using(bucket_id = 'holdout' and is_admin()) with check(bucket_id = 'holdout' and is_admin());
