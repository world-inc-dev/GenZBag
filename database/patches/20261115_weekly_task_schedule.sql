-- Enforce GenZBag's published weekly activity timetable in East Africa Time.
-- Sunday=0, Monday=1, ... Saturday=6.

create or replace function private.assert_genzbag_task_day(p_task_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text;
  v_category text;
  v_required_day integer;
  v_today integer := extract(dow from (now() at time zone 'Africa/Kampala'))::integer;
  v_day_name text;
  v_required_name text;
begin
  select lower(coalesce(t.title,'')), lower(coalesce(t.category,''))
    into v_title, v_category
  from public.tasks t
  where t.id = p_task_id;

  if not found then
    raise exception 'This scheduled activity could not be found.';
  end if;

  v_required_day := case
    when v_category = 'music' then 1
    when v_category = 'video' and v_title like '%youtube%' then 3
    when v_category = 'video' and v_title like '%tiktok%' then 4
    when v_category = 'sponsored' then 0
    when v_category = 'challenge' or v_title like '%trivia%' then 3
    when v_title like '%colour%' or v_title like '%color%' then 2
    when v_title like '%math%' then 6
    when v_title like '%casino%' or v_title like '%spin%' then 5
    when v_title like '%tap earning%' then 2
    else null
  end;

  if v_required_day is null then return; end if;
  if v_today <> v_required_day then
    v_day_name := (array['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'])[v_today+1];
    v_required_name := (array['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'])[v_required_day+1];
    raise exception 'This task is scheduled for % only. Today is % in East Africa Time (Uganda).', v_required_name, v_day_name
      using errcode = '22023';
  end if;
end;
$$;

create or replace function private.enforce_genzbag_task_day_on_submission()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin perform private.assert_genzbag_task_day(new.task_id); return new; end; $$;

create or replace function private.enforce_genzbag_task_day_on_challenge()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin perform private.assert_genzbag_task_day(new.task_id); return new; end; $$;

create or replace function private.enforce_genzbag_task_day_on_ad_view()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin perform private.assert_genzbag_task_day(new.task_id); return new; end; $$;

drop trigger if exists genzbag_schedule_task_submission on public.task_submissions;
create trigger genzbag_schedule_task_submission
before insert on public.task_submissions
for each row execute function private.enforce_genzbag_task_day_on_submission();

drop trigger if exists genzbag_schedule_challenge_session on private.challenge_sessions;
create trigger genzbag_schedule_challenge_session
before insert or update of submitted_at on private.challenge_sessions
for each row execute function private.enforce_genzbag_task_day_on_challenge();

drop trigger if exists genzbag_schedule_ad_view_session on private.ad_view_sessions;
create trigger genzbag_schedule_ad_view_session
before insert or update of completed_at on private.ad_view_sessions
for each row execute function private.enforce_genzbag_task_day_on_ad_view();

revoke all on function private.assert_genzbag_task_day(uuid) from public, anon, authenticated;
revoke all on function private.enforce_genzbag_task_day_on_submission() from public, anon, authenticated;
revoke all on function private.enforce_genzbag_task_day_on_challenge() from public, anon, authenticated;
revoke all on function private.enforce_genzbag_task_day_on_ad_view() from public, anon, authenticated;
