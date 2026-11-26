-- GenZBag scale-readiness indexes
-- Apply in the Supabase SQL Editor after reviewing the target project's schema.
-- This migration only adds indexes for columns confirmed in the application code.
-- It does not change data, RLS policies, balances, commissions, or account permissions.

create index if not exists profiles_referred_by_idx
  on public.profiles (referred_by)
  where referred_by is not null;

create index if not exists activation_submissions_status_created_idx
  on public.activation_payment_submissions (status, created_at desc);

create index if not exists activation_submissions_user_status_idx
  on public.activation_payment_submissions (user_id, status);

-- Add optional high-value indexes only when the target table/columns exist.
do $$
begin
  if to_regclass('public.reward_ledger') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='reward_ledger' and column_name='user_id')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='reward_ledger' and column_name='created_at') then
    execute 'create index if not exists reward_ledger_user_created_idx on public.reward_ledger (user_id, created_at desc)';
  end if;

  if to_regclass('public.withdrawal_requests') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='withdrawal_requests' and column_name='user_id')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='withdrawal_requests' and column_name='status')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='withdrawal_requests' and column_name='created_at') then
    execute 'create index if not exists withdrawal_requests_user_status_created_idx on public.withdrawal_requests (user_id, status, created_at desc)';
  end if;

  if to_regclass('public.task_submissions') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='task_submissions' and column_name='user_id')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='task_submissions' and column_name='created_at') then
    execute 'create index if not exists task_submissions_user_created_idx on public.task_submissions (user_id, created_at desc)';
  end if;

  if to_regclass('public.tasks') is not null
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='status')
     and exists (select 1 from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='created_at') then
    execute 'create index if not exists tasks_status_created_idx on public.tasks (status, created_at desc)';
  end if;
end
$$;

analyze public.profiles;
analyze public.activation_payment_submissions;
