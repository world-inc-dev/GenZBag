-- READ-ONLY GenZBag referral / commission integrity audit.
-- Run in Supabase SQL Editor. This script does not modify balances or member records.

-- 1) Confirm the actual columns and types before writing any commission migration.
select table_name, column_name, data_type, udt_name, is_nullable
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'profiles',
    'referrals',
    'reward_ledger',
    'platform_income_ledger',
    'activation_payment_submissions'
  )
order by table_name, ordinal_position;

-- 2) Identify triggers attached to referral and activation tables.
select
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgname as trigger_name,
  pg_get_triggerdef(t.oid, true) as trigger_definition,
  p.proname as function_name,
  pg_get_functiondef(p.oid) as function_definition
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal
  and n.nspname = 'public'
  and c.relname in ('profiles', 'referrals', 'activation_payment_submissions')
order by c.relname, t.tgname;

-- 3) Find stored functions whose definitions mention referral or commission logic.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.prokind in ('f', 'p')
  and (
    p.proname ilike '%referr%'
    or p.proname ilike '%commission%'
    or pg_get_functiondef(p.oid) ilike '%referral_commission%'
  )
order by n.nspname, p.proname;

-- 4) Profiles whose assigned upline does not exist.
select child.id as member_id, child.username, child.referred_by as missing_upline_id
from public.profiles child
left join public.profiles parent on parent.id = child.referred_by
where child.referred_by is not null
  and parent.id is null
order by child.username
limit 500;

-- 5) Referral cycles (including self-referrals), with a bounded traversal.
with recursive walk as (
  select
    p.id as start_id,
    p.referred_by as next_id,
    array[p.id]::uuid[] as path,
    false as cycle,
    1 as depth
  from public.profiles p
  where p.referred_by is not null

  union all

  select
    w.start_id,
    parent.referred_by,
    w.path || parent.id,
    parent.id = any(w.path),
    w.depth + 1
  from walk w
  join public.profiles parent on parent.id = w.next_id
  where w.next_id is not null
    and not w.cycle
    and w.depth < 1000
)
select distinct start_id, path, depth
from walk
where cycle
order by depth desc
limit 500;

-- 6) Duplicate reward idempotency keys, if the expected ledger column exists.
select idempotency_key, count(*) as duplicate_count
from public.reward_ledger
where idempotency_key is not null
group by idempotency_key
having count(*) > 1
order by duplicate_count desc
limit 500;

-- 7) Verified activation totals and commission-ledger totals for reconciliation.
-- This is a summary only; it does not infer that every activation must have the same
-- commission amount or create missing credits.
select
  (select count(*) from public.activation_payment_submissions where status = 'verified') as verified_activations,
  (select count(distinct user_id) from public.activation_payment_submissions where status = 'verified') as activated_members,
  (select count(*) from public.reward_ledger where entry_type = 'referral_commission' and direction = 'credit') as commission_credit_entries,
  (select coalesce(sum(amount), 0) from public.reward_ledger where entry_type = 'referral_commission' and direction = 'credit' and currency = 'UGX') as commission_credits_ugx;
