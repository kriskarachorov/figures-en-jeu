-- Run once after 002_gameplay.sql. Read-only XP ranking for signed-in players.
begin;
create or replace function public.get_xp_leaderboard() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 with totals as (
  select u.id, left(coalesce(nullif(trim(u.raw_user_meta_data->>'display_name'),''),'Joueur'),30) nickname,
   coalesce(a.xp,0)+coalesce(r.xp,0)+coalesce(w.xp,0) xp
  from auth.users u
  left join (select user_id,sum(points) xp from public.figure_attempts where round_id is null group by user_id) a on a.user_id=u.id
  left join (select user_id,sum(earned) xp from public.game_rounds group by user_id) r on r.user_id=u.id
  left join (select user_id,sum(score*10) xp from public.weekly_entries where submitted_at is not null group by user_id) w on w.user_id=u.id
 ), ranked as (select *,dense_rank() over(order by xp desc) position from totals),
 top_players as (select * from ranked order by xp desc,nickname,id limit 100)
 select jsonb_build_object(
  'players',coalesce((select jsonb_agg(jsonb_build_object('rank',position,'nickname',nickname,'xp',xp,'me',id=auth.uid()) order by position,nickname,id) from top_players),'[]'::jsonb),
  'me',(select jsonb_build_object('rank',position,'nickname',nickname,'xp',xp,'me',true) from ranked where id=auth.uid())
 ) into result;
 return result;
end $$;
revoke all on function public.get_xp_leaderboard() from public,anon;
grant execute on function public.get_xp_leaderboard() to authenticated;
commit;
