-- GenZBag: release queued task rewards at the start of their scheduled day.
-- pg_cron uses UTC on this project. 21:00 UTC is 00:00 Africa/Kampala (EAT).
create extension if not exists pg_cron with schema pg_catalog;

create or replace function private.release_due_scheduled_task_credits()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_count integer := 0;
  v_today date := (now() at time zone 'Africa/Kampala')::date;
begin
  for r in
    select *
    from private.scheduled_task_credits
    where credited_at is null and eligible_on <= v_today
    order by eligible_on, created_at
    for update
  loop
    insert into public.reward_ledger(
      user_id, entry_type, direction, amount, currency,
      reference_type, reference_id, idempotency_key, note
    )
    values (
      r.user_id, r.entry_type, 'credit', r.amount, r.currency,
      r.reference_type, r.reference_id, r.idempotency_key, r.note
    )
    on conflict (idempotency_key) do nothing;

    update private.scheduled_task_credits
    set credited_at = now()
    where id = r.id and credited_at is null;

    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke all on function private.release_due_scheduled_task_credits()
from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'genzbag-release-weekly-task-credits';

select cron.schedule(
  'genzbag-release-weekly-task-credits',
  '0 21 * * *',
  'select private.release_due_scheduled_task_credits();'
);
