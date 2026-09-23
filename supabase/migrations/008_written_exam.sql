-- Written exams: private submissions, bounded AI calls and server-only rewards.
begin;
create table public.written_exams (
 user_id uuid not null references auth.users(id) on delete cascade,
 id uuid not null, answers jsonb not null, status text not null default 'pending',
 claim uuid not null, started_at timestamptz not null default now(),
 created_at timestamptz not null default now(), attempts int not null default 1,
 result jsonb, primary key(user_id,id)
);
create table public.written_calls (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id) on delete cascade,
 called_at timestamptz not null default now(),
 claim uuid not null unique, reserved_micro_usd bigint not null, charged_micro_usd bigint not null
);
alter table public.written_exams enable row level security;
alter table public.written_calls enable row level security;
revoke all on public.written_exams,public.written_calls from public,anon,authenticated;
create index written_calls_time on public.written_calls(called_at);
create index written_calls_user_time on public.written_calls(user_id,called_at);

create or replace function public.get_written_exam(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare r public.written_exams;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 select * into r from public.written_exams where user_id=auth.uid() and id=p_id;
 if not found then return null;end if;
 return jsonb_build_object('status',r.status,'result',r.result);
end $$;
revoke all on function public.get_written_exam(uuid) from public,anon;
grant execute on function public.get_written_exam(uuid) to authenticated;

-- Called only by the authenticated Edge Function, never by the browser.
create or replace function public.claim_written_exam(p_user uuid,p_id uuid,p_answers jsonb,p_reserve bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.written_exams;a jsonb;f int;ex int;seen int[]:='{}';token uuid:=gen_random_uuid();boundary timestamptz:=date_trunc('day',now() at time zone 'Europe/Sofia') at time zone 'Europe/Sofia';
begin
 if p_reserve is null or p_reserve not between 1 and 250000 then raise exception 'Invalid reservation';end if;
 if p_user is null or p_id is null or not exists(select 1 from auth.users where id=p_user) then raise exception 'Invalid user';end if;
 if p_answers is null or jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>24 then raise exception 'Invalid copy';end if;
 for a in select * from jsonb_array_elements(p_answers) loop
  f:=(a->>'figureId')::int;ex:=(a->>'exampleIndex')::int;
  if f is null or f not between 0 and 23 or f=any(seen) or ex is null or ex not between 0 and 3
   or coalesce(a->>'type','') not in ('name','example')
   or jsonb_typeof(a->'name') is distinct from 'string' or length(a->>'name')>80
   or jsonb_typeof(a->'definition') is distinct from 'string' or length(a->>'definition')>600
   or jsonb_typeof(a->'example') is distinct from 'string' or length(a->>'example')>600 then raise exception 'Invalid answer';end if;
  seen:=array_append(seen,f);
 end loop;
 -- One global transaction lock makes both quotas atomic across concurrent calls.
 perform pg_advisory_xact_lock(hashtextextended('written-ai-budget',0));
 select * into r from public.written_exams where user_id=p_user and id=p_id for update;
 if found then
  if r.answers<>p_answers then raise exception 'Copy already submitted';end if;
  if r.status='graded' then return jsonb_build_object('status','graded','result',r.result);end if;
  if r.status='pending' and r.started_at>now()-interval '150 seconds' then return jsonb_build_object('status','pending');end if;
  if r.attempts>=2 then raise exception 'RETRY_LIMIT';end if;
 end if;
 if now()>='2026-09-25 00:00:00 Europe/Sofia'::timestamptz then raise exception 'CAMPAIGN_ENDED';end if;
 if (select coalesce(sum(charged_micro_usd),0) from public.written_calls)+p_reserve>4000000 then raise exception 'CAMPAIGN_BUDGET';end if;
 if (select count(*) from public.written_calls where called_at>=boundary)>=200 then raise exception 'DAILY_SITE_LIMIT';end if;
 if (select count(*) from public.written_calls where user_id=p_user and called_at>=boundary)>=10 then raise exception 'DAILY_USER_LIMIT';end if;
 if exists(select 1 from public.game_rounds where user_id=p_user and id=p_id) then raise exception 'Result ID already used';end if;
 insert into public.written_calls(user_id,claim,reserved_micro_usd,charged_micro_usd) values(p_user,token,p_reserve,p_reserve);
 insert into public.written_exams(user_id,id,answers,claim) values(p_user,p_id,p_answers,token)
 on conflict(user_id,id) do update set claim=token,started_at=now(),status='pending',attempts=public.written_exams.attempts+1;
 return jsonb_build_object('status','claimed','claim',token);
end $$;
revoke all on function public.claim_written_exam(uuid,uuid,jsonb,bigint) from public,anon,authenticated;
grant execute on function public.claim_written_exam(uuid,uuid,jsonb,bigint) to service_role;

create or replace function public.fail_written_exam(p_user uuid,p_id uuid,p_claim uuid) returns void
language sql security definer set search_path='' as $$
 update public.written_exams set status='failed' where user_id=p_user and id=p_id and claim=p_claim and status='pending';
$$;
revoke all on function public.fail_written_exam(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.fail_written_exam(uuid,uuid,uuid) to service_role;

create or replace function public.finish_written_exam(p_user uuid,p_id uuid,p_claim uuid,p_items jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r public.written_exams;a jsonb;g jsonb;f int;c int;ds numeric;ans numeric;uncertain bool;ok bool;uses int;xp int:=0;streak int:=0;best int:=0;credited int:=0;total numeric:=0;normalized jsonb:='[]';items jsonb:='[]';final_result jsonb;d date:=(now() at time zone 'Europe/Sofia')::date;seen int[]:='{}';
 mapping int[]:=array[32,9,33,2,26,24,34,25,14,27,10,5,30,13,35,36,37,23,38,12,39,40,41,22];
begin
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 select * into r from public.written_exams where user_id=p_user and id=p_id for update;
 if not found or r.claim<>p_claim then raise exception 'Invalid claim';end if;
 if r.status='graded' then return r.result;end if;
 if r.status<>'pending' then raise exception 'Not pending';end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)<>24 then raise exception 'Invalid grading';end if;
 for g in select * from jsonb_array_elements(p_items) loop
  f:=(g->>'figureId')::int;ds:=(g->>'definitionScore')::numeric;ans:=(g->>'answerScore')::numeric;uncertain:=(g->>'uncertain')::boolean;
  if f is null or f not between 0 and 23 or f=any(seen) or ds is null or ds not in (0,0.5,1) or ans is null or ans not in (0,0.5,1) or uncertain is null or jsonb_typeof(g->'feedback') is distinct from 'string' or length(g->>'feedback') not between 1 and 800 then raise exception 'Invalid grade';end if;
  seen:=array_append(seen,f);
 end loop;
 for a in select * from jsonb_array_elements(r.answers) loop
  f:=(a->>'figureId')::int;c:=mapping[f+1];select value into g from jsonb_array_elements(p_items) where (value->>'figureId')::int=f;
  ds:=(g->>'definitionScore')::numeric;ans:=(g->>'answerScore')::numeric;uncertain:=(g->>'uncertain')::boolean;
  if trim(a->>'definition')='' or uncertain then ds:=0;end if;
  if trim(case when a->>'type'='name' then a->>'example' else a->>'name' end)='' or uncertain then ans:=0;end if;
  total:=total+ds+ans;ok:=ds=1 and ans=1 and not uncertain;
  if ok then
   streak:=streak+1;best:=greatest(best,streak);
   select gc.uses into uses from public.game_credits gc where gc.user_id=p_user and gc.day=d and gc.figure_id=c;
   if coalesce(uses,0)<2 then
    xp:=xp+10;credited:=credited+1;
    insert into public.game_credits values(p_user,d,c,1) on conflict(user_id,day,figure_id) do update set uses=public.game_credits.uses+1;
   end if;
  else streak:=0;end if;
  items:=items||jsonb_build_array(jsonb_build_object('figureId',f,'definitionScore',ds,'answerScore',ans,'uncertain',uncertain,'feedback',g->>'feedback'));
  normalized:=normalized||jsonb_build_array(jsonb_build_object('figureId',f,'canonicalId',c,'questionId',f*100+case when a->>'type'='name' then 99 else (a->>'exampleIndex')::int end,'selectedId',case when ok then f else null end,'reasonId',case when ds=1 then f else null end,'hinted',false,'correct',ok,'writtenScore',ds+ans));
 end loop;
 if best>=5 and credited>=5 then xp:=xp+5;end if;
 if (select count(distinct figure_id) from (
  select figure_id from public.figure_attempts where user_id=p_user and correct and not used_hint and (answered_at at time zone 'Europe/Sofia')::date=d
  union all select (item->>'canonicalId')::int from public.game_rounds gr cross join lateral jsonb_array_elements(gr.answers) item where gr.user_id=p_user and gr.mode like 'thursday_%' and (gr.completed_at at time zone 'Europe/Sofia')::date=d and (item->>'correct')::boolean and not (item->>'hinted')::boolean
  union all select (item->>'canonicalId')::int from jsonb_array_elements(normalized) item where (item->>'correct')::boolean
 ) today)>=5 then
  insert into public.game_quests values(p_user,d) on conflict do nothing;if found then xp:=xp+25;end if;
 end if;
 insert into public.game_rounds(user_id,id,mode,answers,earned,best_combo) values(p_user,p_id,'thursday_written',normalized,xp,best);
 final_result:=jsonb_build_object('id',p_id,'items',items,'score',round(total/48*20,1),'earned',xp);
 update public.written_exams set status='graded',result=final_result where user_id=p_user and id=p_id;
 return final_result;
end $$;
revoke all on function public.finish_written_exam(uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.finish_written_exam(uuid,uuid,uuid,jsonb) to service_role;
-- Settle successful measured usage; uncertain/failed calls retain their reservation.
create or replace function public.settle_written_call(p_claim uuid,p_micro_usd bigint) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_micro_usd is null or p_micro_usd<0 then raise exception 'Invalid usage';end if;
 perform pg_advisory_xact_lock(hashtextextended('written-ai-budget',0));
 update public.written_calls set charged_micro_usd=p_micro_usd where claim=p_claim;
end $$;
revoke all on function public.settle_written_call(uuid,bigint) from public,anon,authenticated;
grant execute on function public.settle_written_call(uuid,bigint) to service_role;
commit;
