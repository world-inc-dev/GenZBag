-- GenZBag production hardening patch
-- Applied to Supabase project pihesnxftmrzmsoikvfz on 2026-11-14.
-- This is an incremental patch for the existing GenZBag baseline schema, not a standalone schema bootstrap.

-- 1) Allow the separately labelled mobile-money methods while preserving legacy records.
alter table public.activation_payment_submissions
  drop constraint if exists activation_payment_submissions_payment_method_check;
alter table public.activation_payment_submissions
  add constraint activation_payment_submissions_payment_method_check
  check (payment_method = any (array['mobile_money','mtn_mobile_money','airtel_money','grandfathered']::text[]));

alter table public.activation_payment_submissions
  drop constraint if exists activation_reference_required;
alter table public.activation_payment_submissions
  add constraint activation_reference_required
  check (
    (payment_method = 'grandfathered' and amount = 0 and status = 'verified')
    or (
      payment_method in ('mobile_money','mtn_mobile_money','airtel_money')
      and amount = 19500
      and payment_reference is not null
      and length(btrim(payment_reference)) between 5 and 120
    )
  );

drop policy if exists activation_insert_own_pending on public.activation_payment_submissions;
create policy activation_insert_own_pending
on public.activation_payment_submissions
for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and amount = 19500
  and currency = 'UGX'
  and payment_method in ('mobile_money','mtn_mobile_money','airtel_money')
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and admin_note is null
);

-- 2) Prevent duplicate references, duplicate pending submissions and repeat verified activation awards.
create unique index if not exists activation_payment_reference_unique_idx
  on public.activation_payment_submissions (lower(btrim(payment_reference)))
  where payment_reference is not null and payment_method <> 'grandfathered';
create unique index if not exists activation_one_pending_per_user_idx
  on public.activation_payment_submissions (user_id) where status = 'pending';
create unique index if not exists activation_one_verified_per_user_idx
  on public.activation_payment_submissions (user_id) where status = 'verified';

-- 3) Keep the administrator financial summary accurate for MTN and Airtel.
create or replace function public.admin_financial_summary()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
 a numeric(14,2):=0; ac bigint:=0; rc numeric(14,2):=0; rb numeric(14,2):=0;
 oc numeric(14,2):=0; ob numeric(14,2):=0; wr numeric(14,2):=0; wc bigint:=0;
 wp numeric(14,2):=0; pc bigint:=0; pi numeric(14,2):=0; retained numeric(14,2):=0;
begin
 if coalesce(auth.jwt()->>'role','')<>'service_role'
    and coalesce(auth.jwt()->'app_metadata'->>'role','')<>'admin' then
  raise exception 'Administrator authorization required' using errcode='42501';
 end if;
 select coalesce(sum(amount),0),count(*) into a,ac
 from public.activation_payment_submissions
 where status='verified'
   and payment_method in ('mobile_money','mtn_mobile_money','airtel_money')
   and currency='UGX';
 select
  coalesce(sum(case when entry_type='referral_commission' and direction='credit' then amount else 0 end),0),
  coalesce(sum(case
    when entry_type='referral_commission' and direction='credit' then amount
    when entry_type='referral_commission' and direction='debit' then -amount
    when entry_type='withdrawal_debit' and direction='debit' then -amount
    when entry_type='withdrawal_debit' and direction='credit' then amount
    when entry_type='withdrawal_reversal' and direction='credit' then amount
    when entry_type='withdrawal_reversal' and direction='debit' then -amount else 0 end),0),
  coalesce(sum(case when entry_type in ('task_reward','adjustment') and direction='credit' then amount else 0 end),0),
  coalesce(sum(case when entry_type in ('task_reward','adjustment') and direction='credit' then amount
                    when entry_type in ('task_reward','adjustment') and direction='debit' then -amount else 0 end),0)
 into rc,rb,oc,ob from public.reward_ledger where currency='UGX';
 select coalesce(sum(amount),0) into pi from public.platform_income_ledger where currency='UGX';
 select coalesce(sum(amount),0),count(*) into wr,wc
 from public.withdrawal_requests where currency='UGX' and status in ('pending','under_review','approved');
 select coalesce(sum(amount),0),count(*) into wp,pc
 from public.withdrawal_requests where currency='UGX' and status='paid';
 retained:=a-rc-oc;
 return jsonb_build_object(
  'currency','UGX','activation_income',a,'verified_paid_activations',ac,
  'referral_commissions_credited',rc,'referral_commissions_outstanding',rb,
  'other_rewards_credited',oc,'other_rewards_outstanding',ob,
  'total_rewards_outstanding',rb+ob,'withdrawals_reserved',wr,
  'open_withdrawal_count',wc,'withdrawals_paid',wp,'paid_withdrawal_count',pc,
  'platform_unallocated_referral_income',pi,'platform_retained_before_expenses',retained,
  'welcome_bonus_excluded',true,'updated_at',now()
 );
end;
$function$;

-- 4) Add indexes for frequently joined foreign-key columns.
create index if not exists activation_payment_submissions_reviewed_by_idx
  on public.activation_payment_submissions(reviewed_by);
create index if not exists email_outbox_activation_submission_id_idx
  on public.email_outbox(activation_submission_id);
create index if not exists email_outbox_user_id_idx
  on public.email_outbox(user_id);
create index if not exists global_chat_reports_reporter_id_idx
  on public.global_chat_reports(reporter_id);
create index if not exists platform_income_ledger_activation_submission_id_idx
  on public.platform_income_ledger(activation_submission_id);

-- 5) Optimise selected RLS expressions using scalar subqueries for auth claims.
drop policy if exists activation_admin_update on public.activation_payment_submissions;
create policy activation_admin_update
on public.activation_payment_submissions
for update to authenticated
using (((select auth.jwt())->'app_metadata'->>'role')='admin')
with check (((select auth.jwt())->'app_metadata'->>'role')='admin');

drop policy if exists activation_read_own_or_admin on public.activation_payment_submissions;
create policy activation_read_own_or_admin
on public.activation_payment_submissions
for select to authenticated
using ((select auth.uid())=user_id or ((select auth.jwt())->'app_metadata'->>'role')='admin');

drop policy if exists global_chat_reports_read_own_or_admin on public.global_chat_reports;
create policy global_chat_reports_read_own_or_admin
on public.global_chat_reports
for select to authenticated
using ((select auth.uid())=reporter_id or ((select auth.jwt())->'app_metadata'->>'role')='admin');

-- 6) Remove anonymous access to member data and apply least-privilege column grants.
revoke all on table
 public.profiles, public.tasks, public.task_submissions, public.referrals,
 public.reward_ledger, public.withdrawal_requests, public.notifications,
 public.support_tickets, public.platform_settings, public.admin_audit_logs,
 public.engagement_activities, public.engagement_sessions, public.global_chat_members,
 public.global_chat_messages, public.global_chat_reports, public.member_conversations,
 public.member_directory, public.member_messages, public.activation_payment_submissions,
 public.email_outbox, public.platform_income_ledger
from anon;

revoke insert, update, delete on table public.profiles from authenticated;
grant update (phone, contact_email) on table public.profiles to authenticated;

revoke insert, update, delete on table public.task_submissions from authenticated;
grant insert (task_id, user_id, proof_text, proof_url) on table public.task_submissions to authenticated;

revoke insert, update, delete on table public.activation_payment_submissions from authenticated;
grant insert (user_id, amount, currency, payment_method, payment_reference)
on table public.activation_payment_submissions to authenticated;

revoke insert, update, delete on table public.withdrawal_requests from authenticated;

revoke insert, update, delete on table public.support_tickets from authenticated;
grant insert (user_id, subject, message, priority) on table public.support_tickets to authenticated;
grant update (status, priority, updated_at) on table public.support_tickets to authenticated;

revoke insert, update, delete on table public.notifications from authenticated;
grant update (read_at) on table public.notifications to authenticated;

revoke insert, update, delete on table public.global_chat_members from authenticated;
grant insert (user_id, display_name, country) on table public.global_chat_members to authenticated;
grant update (user_id, display_name, country) on table public.global_chat_members to authenticated;

revoke insert, update, delete on table public.global_chat_messages from authenticated;
grant insert (user_id, message) on table public.global_chat_messages to authenticated;

revoke insert, update, delete on table public.global_chat_reports from authenticated;
grant insert (message_id, reporter_id, reason) on table public.global_chat_reports to authenticated;

revoke insert, update, delete on table public.member_conversations from authenticated;
grant insert (member_a, member_b) on table public.member_conversations to authenticated;

revoke insert, update, delete on table public.member_messages from authenticated;
grant insert (conversation_id, sender_id, body) on table public.member_messages to authenticated;

revoke insert, update, delete on table public.engagement_sessions from authenticated;
grant insert (activity_id, user_id, evidence, submitted_at) on table public.engagement_sessions to authenticated;

revoke insert, update, delete on table public.platform_settings from authenticated;
