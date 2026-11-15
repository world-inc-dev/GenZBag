-- Direct-reward activities are also restricted by the Kampala weekly timetable.
-- Tap Earnings: Tuesday (2); Casino & Spin: Friday (5); Foreign Chat bonus: Monday (1).

create or replace function public.claim_tap_earnings()
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_uid uuid:=auth.uid(); v_day date:=(timezone('Africa/Kampala',now()))::date; v_count integer; v_attempt uuid; v_amount numeric:=500;
begin
 if v_uid is null then raise exception 'Sign in to earn from Tap Earnings' using errcode='42501'; end if;
 if not public.current_user_is_activated() then raise exception 'Activate your account before using paid-reward activities' using errcode='42501'; end if;
 if extract(dow from timezone('Africa/Kampala',now()))::integer <> 2 then raise exception 'Tap Earnings is available on Tuesday only (East Africa Time).' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text||':tap:'||v_day::text,0));
 select count(*) into v_count from private.daily_activity_attempts where user_id=v_uid and activity_key='tap' and local_date=v_day;
 if v_count>=2 then raise exception 'You have used both Tap Earnings attempts for today. Come back tomorrow.' using errcode='23514'; end if;
 insert into private.daily_activity_attempts(user_id,activity_key,local_date,amount) values(v_uid,'tap',v_day,v_amount) returning id into v_attempt;
 insert into public.reward_ledger(user_id,entry_type,direction,amount,currency,reference_type,reference_id,idempotency_key,note)
 values(v_uid,'task_reward','credit',v_amount,'UGX','tap_activity',v_attempt,'tap_activity:'||v_attempt::text,'Tap Earnings reward');
 v_count:=v_count+1;
 return jsonb_build_object('success',true,'reward',v_amount,'currency','UGX','attempts_used',v_count,'attempts_remaining',2-v_count,'daily_limit',2,'message','UGX 500 has been added to your Net Profits.');
end $function$;

create or replace function public.spin_and_win()
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_uid uuid:=auth.uid(); v_day date:=(timezone('Africa/Kampala',now()))::date; v_count integer; v_attempt uuid; v_index integer; v_amount numeric; v_amounts numeric[]:=array[100,200,500,1000,2000,5000]::numeric[];
begin
 if v_uid is null then raise exception 'Sign in to play Spin & Win' using errcode='42501'; end if;
 if not public.current_user_is_activated() then raise exception 'Activate your account before using paid-reward activities' using errcode='42501'; end if;
 if extract(dow from timezone('Africa/Kampala',now()))::integer <> 5 then raise exception 'Casino & Spin is available on Friday only (East Africa Time).' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text||':spin:'||v_day::text,0));
 select count(*) into v_count from private.daily_activity_attempts where user_id=v_uid and activity_key='spin' and local_date=v_day;
 if v_count>=2 then raise exception 'You have used both Spin & Win attempts for today. Come back tomorrow.' using errcode='23514'; end if;
 v_index:=1+floor(random()*array_length(v_amounts,1))::integer;
 v_amount:=v_amounts[v_index];
 insert into private.daily_activity_attempts(user_id,activity_key,local_date,amount) values(v_uid,'spin',v_day,v_amount) returning id into v_attempt;
 insert into public.reward_ledger(user_id,entry_type,direction,amount,currency,reference_type,reference_id,idempotency_key,note)
 values(v_uid,'task_reward','credit',v_amount,'UGX','spin_activity',v_attempt,'spin_activity:'||v_attempt::text,'Spin & Win reward · UGX '||v_amount::text);
 v_count:=v_count+1;
 return jsonb_build_object('success',true,'amount',v_amount,'currency','UGX','segment_index',v_index-1,'attempts_used',v_count,'attempts_remaining',2-v_count,'daily_limit',2,'message','UGX '||to_char(v_amount,'FM999,999,999,990')||' has been added to your Net Profits.');
end $function$;

create or replace function public.claim_foreign_chat_bonus()
returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare v_user uuid:=auth.uid(); v_count integer; v_existing boolean;
begin
 if v_user is null then raise exception 'Please sign in to claim this bonus.'; end if;
 if not public.current_user_is_activated() then raise exception 'Activate your GenZBag account before using chat rewards.'; end if;
 if extract(dow from timezone('Africa/Kampala',now()))::integer <> 1 then raise exception 'Foreign Chat is available on Monday only (East Africa Time).' using errcode='22023'; end if;
 select count(distinct case when c.member_a = v_user then c.member_b else c.member_a end)
 into v_count
 from public.member_conversations c
 where c.initiated_by = v_user
 and exists (select 1 from public.member_messages m where m.conversation_id = c.id and m.sender_id = v_user)
 and exists (select 1 from public.member_messages m where m.conversation_id = c.id and m.sender_id <> v_user);
 if v_count < 5 then
  return jsonb_build_object('success', false, 'qualified', v_count, 'required', 5, 'message', 'Complete genuine conversations with five different members first.');
 end if;
 select exists(select 1 from public.reward_ledger where user_id = v_user and idempotency_key = 'foreign_chat_bonus:' || v_user::text) into v_existing;
 if v_existing then
  return jsonb_build_object('success', false, 'already_claimed', true, 'message', 'Your foreign chat bonus has already been claimed.');
 end if;
 insert into public.reward_ledger(user_id, entry_type, direction, amount, currency, reference_type, idempotency_key, note)
 values (v_user, 'task_reward', 'credit', 10000, 'UGX', 'foreign_chat', 'foreign_chat_bonus:' || v_user::text, 'Foreign chat bonus: five verified conversations with different members');
 return jsonb_build_object('success', true, 'amount', 10000, 'currency', 'UGX', 'qualified', v_count, 'message', 'UGX 10,000 added to Net Profits.');
end;
$function$;
