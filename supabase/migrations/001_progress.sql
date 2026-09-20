-- Figures en jeu: run once in the new project's SQL Editor.
-- Accounts and passwords are managed by Supabase Auth, never by these tables.
begin;

create table public.figure_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  attempt_id uuid not null,
  figure_id integer not null check (figure_id between 0 and 31),
  selected_id integer not null check (selected_id between 0 and 31),
  used_hint boolean not null default false,
  mode text not null check (mode in ('practice', 'test')),
  correct boolean generated always as (figure_id = selected_id) stored,
  points integer generated always as (
    case when figure_id <> selected_id then 0 when used_hint then 5 else 10 end
  ) stored,
  answered_at timestamptz not null default now(),
  primary key (user_id, attempt_id)
);
create index figure_attempts_user_time on public.figure_attempts(user_id, answered_at desc);
alter table public.figure_attempts enable row level security;
revoke all on public.figure_attempts from public, anon, authenticated;
grant select on public.figure_attempts to authenticated;
create policy read_own_attempts on public.figure_attempts
  for select to authenticated using ((select auth.uid()) = user_id);

-- Retries use the same attempt UUID, so a network retry cannot award points twice.
-- Personal practice record, not a tamper-proof competitive leaderboard.
create function public.record_figure_answer(
  p_attempt_id uuid, p_figure_id integer, p_selected_id integer,
  p_used_hint boolean, p_mode text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  saved public.figure_attempts;
begin
  if uid is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_attempt_id is null or p_figure_id is null or p_selected_id is null
     or p_used_hint is null or p_mode is null
     or p_figure_id not between 0 and 31 or p_selected_id not between 0 and 31
     or p_mode not in ('practice', 'test') or (p_mode = 'test' and p_used_hint)
  then raise exception 'Invalid answer' using errcode = '22023'; end if;

  insert into public.figure_attempts(user_id, attempt_id, figure_id, selected_id, used_hint, mode)
  values(uid, p_attempt_id, p_figure_id, p_selected_id, p_used_hint, p_mode)
  on conflict (user_id, attempt_id) do nothing;

  select * into saved from public.figure_attempts
    where user_id = uid and attempt_id = p_attempt_id;
  if saved.figure_id <> p_figure_id or saved.selected_id <> p_selected_id
     or saved.used_hint <> p_used_hint or saved.mode <> p_mode
  then raise exception 'Attempt already recorded with different data' using errcode = '22023'; end if;
  return jsonb_build_object('attempt_id', saved.attempt_id, 'correct', saved.correct, 'points', saved.points);
end;
$$;
revoke all on function public.record_figure_answer(uuid,integer,integer,boolean,text) from public, anon;
grant execute on function public.record_figure_answer(uuid,integer,integer,boolean,text) to authenticated;

create function public.get_figure_progress()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'points', coalesce(sum(points),0),
    'answered', count(*),
    'correct', count(*) filter (where correct),
    'unassisted_correct', count(*) filter (where correct and not used_hint),
    'figures', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', figure_id, 'answered', n, 'correct', c, 'unassisted_correct', u, 'last_answered', last_answered
      ) order by figure_id)
      from (
        select figure_id, count(*) n, count(*) filter (where correct) c,
          count(*) filter (where correct and not used_hint) u, max(answered_at) last_answered
        from public.figure_attempts where user_id = (select auth.uid()) group by figure_id
      ) per_figure
    ), '[]'::jsonb)
  ) from public.figure_attempts where user_id = (select auth.uid());
$$;
revoke all on function public.get_figure_progress() from public, anon;
grant execute on function public.get_figure_progress() to authenticated;

commit;
