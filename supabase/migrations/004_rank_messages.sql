-- Rank notifications for a just-saved round or weekly challenge.
begin;
create or replace function public.get_xp_overtake(p_round uuid default null,p_week date default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid();reward integer;finished timestamptz;result jsonb;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 if (p_round is null)=(p_week is null) then raise exception 'Choose one saved result';end if;
 if p_round is not null then
  select earned,completed_at into reward,finished from public.game_rounds where user_id=u and id=p_round;
 else
  select score*10,submitted_at into reward,finished from public.weekly_entries where user_id=u and week=p_week and submitted_at is not null;
 end if;
 if coalesce(reward,0)<=0 or finished is null then return null;end if;
 -- Do not attribute a later award from another tab to this round.
 if exists(select 1 from public.game_rounds where user_id=u and completed_at>finished)
 or exists(select 1 from public.weekly_entries where user_id=u and submitted_at>finished)
 or exists(select 1 from public.figure_attempts where user_id=u and round_id is null and answered_at>finished)
 then return null;end if;
 with totals as (
  select users.id,left(coalesce(nullif(trim(users.raw_user_meta_data->>'display_name'),''),'Joueur'),30) nickname,
   coalesce(a.xp,0)+coalesce(r.xp,0)+coalesce(w.xp,0) xp
  from auth.users users
  left join (select user_id,sum(points) xp from public.figure_attempts where round_id is null group by user_id) a on a.user_id=users.id
  left join (select user_id,sum(earned) xp from public.game_rounds group by user_id) r on r.user_id=users.id
  left join (select user_id,sum(score*10) xp from public.weekly_entries where submitted_at is not null group by user_id) w on w.user_id=users.id
 ), mine as (select xp,xp-reward previous_xp from totals where id=u),
 passed as (select t.* from totals t,mine m where t.id<>u and t.xp>m.previous_xp and t.xp<m.xp)
 select case when exists(select 1 from passed) then jsonb_build_object(
  'nickname',(select nickname from passed order by xp desc,nickname,id limit 1),
  'passed_count',(select count(*) from passed),
  'rank',(select 1+count(distinct t.xp) from totals t,mine m where t.id<>u and t.xp>m.xp)
 ) else null end into result;
 return result;
end $$;
revoke all on function public.get_xp_overtake(uuid,date) from public,anon;
grant execute on function public.get_xp_overtake(uuid,date) to authenticated;
commit;
