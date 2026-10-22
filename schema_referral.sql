-- ======================================================================
-- BFT Partner (referral) programme v1.  Run in Supabase SQL Editor AFTER schema.sql and schema_pricing.sql. Safe to re-run.
--
-- How it works
--   * Anyone with a confirmed account can become a partner (referral.html) and gets a code, e.g. SAIF3F9A.
--   * Link: https://your-site/index.html?ref=SAIF3F9A  -> ref.js remembers the code for 30 days (last click wins).
--   * razorpay-order checks the code and puts it in the order notes. razorpay-webhook writes one row in `referrals`
--     per captured payment: commission = amount * rate / 100 (default 30%).
--   * pending -> (hold period, 10 days, longer than the 7-day refund window) -> approved -> paid by admin (UPI) -> `payouts`.
--   * Refund before payout: row becomes void. Refund after payout: clawback, netted off the next payout.
--   * Partners and visitors never read tables directly. They use the functions below (security definer), so a partner
--     only ever sees their own numbers and buyers' emails are masked.
-- Tune: hold days -> HOLD_DAYS in razorpay-webhook + partner_dashboard(); min payout -> partner_dashboard(); rate -> referrers.rate.
-- ======================================================================

create table if not exists referrers(
  email text primary key,                       -- lower-case account email
  code text not null unique,                    -- UPPER-CASE, 6-8 chars
  name text not null,
  upi text,
  rate int not null default 30 check(rate between 0 and 60),   -- percent
  active boolean not null default true,
  created_at timestamptz default now());

create table if not exists referral_clicks(     -- unique visitor per code per day
  code text not null, vid text not null, day date not null default (now() at time zone 'Asia/Kolkata')::date,   -- India day
  primary key(code, vid, day));
create index if not exists referral_clicks_day_idx on referral_clicks(code, day);

create table if not exists payouts(
  id bigint generated always as identity primary key,
  referrer_email text not null, amount int not null, utr text, note text,
  created_at timestamptz default now());

create table if not exists referrals(
  payment_id text primary key,                  -- Razorpay payment id => webhook retries are harmless
  code text not null, referrer_email text not null, buyer_email text not null,
  product_id text, amount int not null, rate int not null, commission int not null,
  status text not null default 'pending' check(status in('pending','approved','paid','void')),
  refunded boolean not null default false,      -- customer was refunded
  adjusted boolean not null default false,      -- clawback already netted off a payout
  approve_after timestamptz not null,
  paid_at timestamptz, payout_id bigint references payouts(id),
  created_at timestamptz default now());
create index if not exists referrals_ref_idx on referrals(referrer_email, created_at desc);

alter table referrers enable row level security;
alter table referral_clicks enable row level security;
alter table referrals enable row level security;
alter table payouts enable row level security;
drop policy if exists rr_admin on referrers;        create policy rr_admin on referrers        for all using(is_admin()) with check(is_admin());
drop policy if exists rc_admin on referral_clicks;  create policy rc_admin on referral_clicks  for all using(is_admin()) with check(is_admin());
drop policy if exists rf_admin on referrals;        create policy rf_admin on referrals        for all using(is_admin()) with check(is_admin());
drop policy if exists po_admin on payouts;          create policy po_admin on payouts          for all using(is_admin()) with check(is_admin());

-- pending -> approved once the hold period is over (and the sale was not refunded)
create or replace function ref_settle() returns void language sql security definer set search_path = public as
$$update referrals set status = 'approved' where status = 'pending' and not refunded and approve_after <= now()$$;
revoke all on function ref_settle() from public, anon, authenticated;

-- a visitor opened a partner link (called by ref.js with the public key). Unique per visitor per day.
create or replace function ref_click(p_code text, p_vid text) returns void language plpgsql security definer set search_path = public as $$
begin
  if p_code is null or p_vid is null or p_code !~ '^[A-Za-z0-9]{4,12}$' or p_vid !~ '^[A-Za-z0-9-]{8,64}$' then return; end if;
  insert into referral_clicks(code, vid)
  select upper(p_code), p_vid where exists(select 1 from referrers r where r.code = upper(p_code) and r.active)
  on conflict do nothing;
end $$;
grant execute on function ref_click(text, text) to anon, authenticated;

-- become a partner (or update name / UPI). Returns the code.
create or replace function join_partner(p_name text, p_upi text) returns text language plpgsql security definer set search_path = public as $$
declare em text := lower(auth.jwt()->>'email'); c text; base text; i int := 0;
begin
  if auth.uid() is null or not exists(select 1 from auth.users u where u.id = auth.uid() and u.email_confirmed_at is not null) then
    raise exception 'Sign in with a confirmed email first'; end if;
  p_name := trim(coalesce(p_name, '')); p_upi := trim(coalesce(p_upi, ''));
  if length(p_name) < 2 or length(p_name) > 60 then raise exception 'Enter your name'; end if;
  if p_upi !~ '^[A-Za-z0-9._-]{2,64}@[A-Za-z0-9]{2,32}$' then raise exception 'Enter a valid UPI ID, like name@upi'; end if;
  select code into c from referrers where email = em;
  if found then update referrers set name = p_name, upi = p_upi where email = em; return c; end if;
  base := upper(left(regexp_replace(p_name, '[^A-Za-z]', '', 'g'), 4));
  if length(base) < 2 then base := 'BFT'; end if;
  loop
    c := base || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 4));
    exit when not exists(select 1 from referrers where code = c);
    i := i + 1; if i > 30 then raise exception 'Please try again'; end if;
  end loop;
  insert into referrers(email, code, name, upi) values(em, c, p_name, p_upi);
  return c;
end $$;
grant execute on function join_partner(text, text) to authenticated;

-- everything the partner dashboard shows, for the signed-in partner only
create or replace function partner_dashboard() returns jsonb language plpgsql security definer set search_path = public as $$
declare em text := lower(auth.jwt()->>'email'); p referrers; clawback int; td date := (now() at time zone 'Asia/Kolkata')::date;
begin
  if auth.uid() is null then raise exception 'Sign in first'; end if;
  select * into p from referrers where email = em;
  if not found then return jsonb_build_object('partner', null); end if;
  perform ref_settle();
  select coalesce(sum(commission), 0) into clawback from referrals where referrer_email = em and status = 'paid' and refunded and not adjusted;
  return jsonb_build_object(
    'partner', jsonb_build_object('code', p.code, 'name', p.name, 'upi', p.upi, 'rate', p.rate, 'active', p.active, 'since', p.created_at),
    'config', jsonb_build_object('hold_days', 10, 'min_payout', 500),
    'clicks', (select count(*) from referral_clicks where code = p.code),
    'clicks30', (select count(*) from referral_clicks where code = p.code and day > td - 30),
    'sales', (select count(*) from referrals where referrer_email = em and status <> 'void'),
    'pending',  (select coalesce(sum(commission), 0) from referrals where referrer_email = em and status = 'pending'),
    'approved', (select coalesce(sum(commission), 0) from referrals where referrer_email = em and status = 'approved'),
    'paid',     (select coalesce(sum(commission), 0) from referrals where referrer_email = em and status = 'paid' and not (refunded and adjusted)),
    'clawback', clawback,
    'series', (select coalesce(jsonb_agg(jsonb_build_object('d', dd,
        'clicks', (select count(*) from referral_clicks c where c.code = p.code and c.day = dd),
        'sales',  (select count(*) from referrals r where r.referrer_email = em and r.status <> 'void' and (r.created_at at time zone 'Asia/Kolkata')::date = dd)) order by dd), '[]'::jsonb)
      from (select td - 29 + g as dd from generate_series(0, 29) g) days),
    'recent', (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) from (
        select r.created_at, left(split_part(r.buyer_email, '@', 1), 2) || '•••' as buyer,
               coalesce(pr.name, it.title, 'BFT') as product, r.amount, r.commission, r.status, r.refunded, r.approve_after
        from referrals r
        left join products pr on pr.id = r.product_id
        left join items it on ('item:' || it.id::text) = r.product_id
        where r.referrer_email = em order by r.created_at desc limit 100) x),
    'payouts', (select coalesce(jsonb_agg(to_jsonb(y) order by y.created_at desc), '[]'::jsonb) from (
        select created_at, amount, utr from payouts where referrer_email = em order by created_at desc limit 50) y)
  );
end $$;
grant execute on function partner_dashboard() to authenticated;

-- ---------------------------------------------------------------- admin
create or replace function admin_referrals() returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  perform ref_settle();
  return jsonb_build_object(
    'partners', (select coalesce(jsonb_agg(to_jsonb(z) order by z.approved desc, z.created_at desc), '[]'::jsonb) from (
        select p.email, p.name, p.code, p.upi, p.rate, p.active, p.created_at,
          (select count(*) from referral_clicks c where c.code = p.code) as clicks,
          (select count(*) from referrals r where r.referrer_email = p.email and r.status <> 'void') as sales,
          (select coalesce(sum(commission), 0) from referrals r where r.referrer_email = p.email and r.status = 'pending') as pending,
          (select coalesce(sum(commission), 0) from referrals r where r.referrer_email = p.email and r.status = 'approved') as approved,
          (select coalesce(sum(commission), 0) from referrals r where r.referrer_email = p.email and r.status = 'paid' and not (r.refunded and r.adjusted)) as paid,
          (select coalesce(sum(commission), 0) from referrals r where r.referrer_email = p.email and r.status = 'paid' and r.refunded and not r.adjusted) as clawback
        from referrers p) z),
    'recent', (select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb) from (
        select r.payment_id, r.created_at, r.referrer_email, r.code, r.buyer_email, coalesce(pr.name, it.title, r.product_id) as product,
               r.amount, r.commission, r.status, r.refunded, r.approve_after
        from referrals r left join products pr on pr.id = r.product_id left join items it on ('item:' || it.id::text) = r.product_id
        order by r.created_at desc limit 150) x),
    'payouts', (select coalesce(jsonb_agg(to_jsonb(y) order by y.created_at desc), '[]'::jsonb) from (
        select created_at, referrer_email, amount, utr, note from payouts order by created_at desc limit 100) y)
  );
end $$;
grant execute on function admin_referrals() to authenticated;

-- pay a partner: all approved commission, minus clawbacks for refunds after an earlier payout. Returns the net rupees to send by UPI.
create or replace function admin_pay_partner(p_email text, p_utr text, p_note text default null) returns int language plpgsql security definer set search_path = public as $$
declare pid bigint; gross int; claw int; net int; em text := lower(trim(p_email));
begin
  if not is_admin() then raise exception 'not admin'; end if;
  perform ref_settle();
  select coalesce(sum(commission), 0) into gross from referrals where referrer_email = em and status = 'approved' and not refunded;
  select coalesce(sum(commission), 0) into claw  from referrals where referrer_email = em and status = 'paid' and refunded and not adjusted;
  net := gross - claw;
  if gross <= 0 then raise exception 'Nothing approved to pay'; end if;
  if net <= 0 then raise exception 'Refund clawback (Rs %) is higher than the approved balance (Rs %). Wait for more sales.', claw, gross; end if;
  insert into payouts(referrer_email, amount, utr, note) values(em, net, nullif(trim(coalesce(p_utr, '')), ''), nullif(trim(coalesce(p_note, '')), '')) returning id into pid;
  update referrals set status = 'paid', paid_at = now(), payout_id = pid where referrer_email = em and status = 'approved' and not refunded;
  update referrals set adjusted = true where referrer_email = em and status = 'paid' and refunded and not adjusted;
  return net;
end $$;
grant execute on function admin_pay_partner(text, text, text) to authenticated;

create or replace function admin_set_partner(p_email text, p_active boolean, p_rate int) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  if p_rate < 0 or p_rate > 60 then raise exception 'Rate must be 0-60'; end if;
  update referrers set active = p_active, rate = p_rate where email = lower(p_email);
end $$;
grant execute on function admin_set_partner(text, boolean, int) to authenticated;

-- cancel one commission (fraud, self-referral that slipped through, etc). Paid rows cannot be voided here.
create or replace function admin_void_referral(p_payment_id text) returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'not admin'; end if;
  update referrals set status = 'void' where payment_id = p_payment_id and status in ('pending', 'approved');
  if not found then raise exception 'Only pending or approved commissions can be cancelled'; end if;
end $$;
grant execute on function admin_void_referral(text) to authenticated;
