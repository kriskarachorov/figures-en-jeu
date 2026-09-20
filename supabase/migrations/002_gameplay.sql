-- Run after 001_progress.sql. Preserves all existing progress.
begin;
alter table public.figure_attempts add column if not exists round_id uuid;
create table if not exists public.game_rounds (
 user_id uuid not null references auth.users(id) on delete cascade,
 id uuid not null, mode text not null, answers jsonb not null,
 earned integer not null, best_combo integer not null, comeback integer not null default 0,
 completed_at timestamptz not null default now(), primary key(user_id,id)
);
create table if not exists public.game_quests(user_id uuid not null references auth.users(id) on delete cascade,day date not null, primary key(user_id,day));
create table if not exists public.game_credits(user_id uuid not null references auth.users(id) on delete cascade,day date not null,figure_id int not null,uses int not null,primary key(user_id,day,figure_id));
alter table public.game_rounds enable row level security;
alter table public.game_quests enable row level security;
alter table public.game_credits enable row level security;
revoke all on public.game_rounds,public.game_quests,public.game_credits from public,anon,authenticated;
grant select on public.game_rounds,public.game_quests to authenticated;
create policy own_rounds on public.game_rounds for select to authenticated using(user_id=(select auth.uid()));
create policy own_quests on public.game_quests for select to authenticated using(user_id=(select auth.uid()));
create or replace function public.submit_game_round(p_id uuid,p_mode text,p_answers jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); d date:=(now() at time zone 'UTC')::date; a jsonb; f int;s int;hint bool;reason int;ok bool;streak int:=0;best int:=0;xp int:=0;credited int:=0;uses int;revenge int:=0;old public.game_rounds;quest bool:=false;previous bool;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_id is null or p_mode is null or p_mode not in ('practice','test','daily','boss','comeback') or p_answers is null or jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers) not between 1 and 32 then raise exception 'Invalid round';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select * into old from public.game_rounds where user_id=u and id=p_id;
 if found then
  if old.mode<>p_mode or old.answers<>p_answers then raise exception 'Round already saved';end if;
  return jsonb_build_object('earned',old.earned,'best_combo',old.best_combo,'comeback',old.comeback,'replayed',true);
 end if;
 if exists(select 1 from jsonb_array_elements(p_answers) x group by x->>'figureId' having count(*)>1) then raise exception 'Repeated figure';end if;
 for a in select * from jsonb_array_elements(p_answers) loop
  f:=(a->>'figureId')::int;s:=(a->>'selectedId')::int;hint:=(a->>'hinted')::boolean;reason:=(a->>'reasonId')::int;
  if f is null or s is null or hint is null or f not between 0 and 31 or s not between 0 and 31 or (p_mode in ('test','boss') and hint) or (p_mode='boss' and (reason is null or reason not between 0 and 31)) or a->>'attemptId' is null then raise exception 'Invalid answer';end if;
  ok:=f=s and (p_mode<>'boss' or reason=f);
  if ok and not hint then streak:=streak+1;best:=greatest(best,streak);else streak:=0;end if;
  select correct into previous from public.figure_attempts where user_id=u and figure_id=f order by answered_at desc limit 1;
  if ok then
   select c.uses into uses from public.game_credits c where c.user_id=u and c.day=d and c.figure_id=f;
   if coalesce(uses,0)<2 then
    xp:=xp+case when hint then 5 else 10 end;credited:=credited+1;
    insert into public.game_credits values(u,d,f,1) on conflict(user_id,day,figure_id) do update set uses=public.game_credits.uses+1;
    if p_mode='comeback' and previous=false and not hint then xp:=xp+5;revenge:=revenge+1;end if;
   end if;
  end if;
  insert into public.figure_attempts(user_id,attempt_id,figure_id,selected_id,used_hint,mode,round_id)
   values(u,(a->>'attemptId')::uuid,f,case when ok then f when s=f then (f+1)%32 else s end,hint,case when p_mode='test' then 'test' else 'practice' end,p_id);
 end loop;
 if best>=5 and credited>=5 then xp:=xp+5;end if;
 if p_mode='boss' and best=jsonb_array_length(p_answers) and credited>0 then xp:=xp+10;end if;
 if (select count(distinct figure_id) from public.figure_attempts where user_id=u and correct and not used_hint and (answered_at at time zone 'UTC')::date=d)>=5 then
  insert into public.game_quests values(u,d) on conflict do nothing;quest:=found;
  if quest then xp:=xp+25;end if;
 end if;
 insert into public.game_rounds(user_id,id,mode,answers,earned,best_combo,comeback) values(u,p_id,p_mode,p_answers,xp,best,revenge);
 return jsonb_build_object('earned',xp,'best_combo',best,'quest',quest,'comeback',revenge,'replayed',false);
end $$;
revoke all on function public.submit_game_round(uuid,text,jsonb) from public,anon;
grant execute on function public.submit_game_round(uuid,text,jsonb) to authenticated;

-- Weekly answers and grading stay on the server. No client-supplied score.
create table if not exists public.weekly_questions(id int primary key,prompt text not null,correct_id int not null,options jsonb not null);
alter table public.weekly_questions enable row level security;
revoke all on public.weekly_questions from public,anon,authenticated;
create table if not exists public.weekly_entries(
 user_id uuid not null references auth.users(id) on delete cascade,week date not null,
 started_at timestamptz not null default now(),submitted_at timestamptz,answers jsonb,score int,
 public_score bool not null default false,nickname text not null default 'Joueur',primary key(user_id,week)
);
alter table public.weekly_entries enable row level security;
revoke all on public.weekly_entries from public,anon,authenticated;
create or replace function public.weekly_pack(p_week date) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_agg(jsonb_build_object('id',id,'prompt',prompt,'options',options) order by ordering) from
 (select q.*,md5(p_week::text||':'||q.id::text) ordering from public.weekly_questions q order by md5(p_week::text||':'||q.id::text) limit 10) chosen;
$$;
revoke all on function public.weekly_pack(date) from public,anon,authenticated;
create or replace function public.start_weekly() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();w date:=date_trunc('week',now() at time zone 'UTC')::date;e public.weekly_entries;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 insert into public.weekly_entries(user_id,week) values(u,w) on conflict do nothing;
 select * into e from public.weekly_entries where user_id=u and week=w;
 return jsonb_build_object('week',w,'questions',public.weekly_pack(w),'submitted',e.submitted_at is not null,'score',e.score,'public_score',e.public_score);
end $$;
create or replace function public.submit_weekly(p_week date,p_answers jsonb,p_public boolean,p_nickname text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();e public.weekly_entries;pack jsonb;q jsonb;a jsonb;n int:=0;v int;
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 select * into e from public.weekly_entries where user_id=u and week=p_week for update;
 if not found then raise exception 'Start the challenge first';end if;
 if e.submitted_at is not null then return jsonb_build_object('score',e.score,'total',10,'replayed',true);end if;
 if p_week<>date_trunc('week',now() at time zone 'UTC')::date then raise exception 'Challenge expired';end if;
 if p_answers is null or jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers)<>10 or p_public is null then raise exception '10 answers required';end if;
 pack:=public.weekly_pack(p_week);
 for q in select * from jsonb_array_elements(pack) loop
  if (select count(*) from jsonb_array_elements(p_answers) x where (x->>'id')::int=(q->>'id')::int)<>1 then raise exception 'Missing or repeated question';end if;
  select x into a from jsonb_array_elements(p_answers) x where (x->>'id')::int=(q->>'id')::int;
  v:=(a->>'selectedId')::int;
  if v is null or not exists(select 1 from jsonb_array_elements(q->'options') o where (o->>'id')::int=v) then raise exception 'Invalid option';end if;
  if v=(select correct_id from public.weekly_questions where id=(q->>'id')::int) then n:=n+1;end if;
 end loop;
 update public.weekly_entries set submitted_at=now(),answers=p_answers,score=n,public_score=p_public,nickname=left(coalesce(nullif(trim(p_nickname),''),'Joueur'),30) where user_id=u and week=p_week;
 return jsonb_build_object('score',n,'total',10,'earned',n*10,'replayed',false);
end $$;
create or replace function public.set_weekly_visibility(p_public boolean,p_nickname text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_public is null then raise exception 'Authentication required';end if;
 update public.weekly_entries set public_score=p_public,nickname=left(coalesce(nullif(trim(p_nickname),''),'Joueur'),30) where user_id=auth.uid() and week=date_trunc('week',now() at time zone 'UTC')::date and submitted_at is not null;
end $$;
create or replace function public.weekly_leaderboard() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('rank',rank,'nickname',nickname,'score',score) order by rank,nickname),'[]'::jsonb) from
 (select dense_rank() over(order by score desc) rank,nickname,score from public.weekly_entries where public_score and submitted_at is not null and week=date_trunc('week',now() at time zone 'UTC')::date limit 100) t;
$$;
revoke all on function public.start_weekly(),public.submit_weekly(date,jsonb,boolean,text),public.set_weekly_visibility(boolean,text),public.weekly_leaderboard() from public,anon;
grant execute on function public.start_weekly(),public.submit_weekly(date,jsonb,boolean,text),public.set_weekly_visibility(boolean,text),public.weekly_leaderboard() to authenticated;
create or replace function public.get_game_state() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object(
 'legacy_points',coalesce((select sum(points) from public.figure_attempts where user_id=auth.uid() and round_id is null),0),
 'rounds',coalesce((select jsonb_agg(to_jsonb(r)-'user_id' order by completed_at) from public.game_rounds r where user_id=auth.uid()),'[]'::jsonb),
 'quests',coalesce((select jsonb_agg(day order by day) from public.game_quests where user_id=auth.uid()),'[]'::jsonb),
 'weekly_xp',coalesce((select sum(score*10) from public.weekly_entries where user_id=auth.uid() and submitted_at is not null),0),
 'attempts',coalesce((select jsonb_agg(jsonb_build_object('figureId',figure_id,'correct',correct,'hinted',used_hint,'date',answered_at,'round',round_id) order by answered_at) from public.figure_attempts where user_id=auth.uid()),'[]'::jsonb));
$$;
revoke all on function public.get_game_state() from public,anon;
grant execute on function public.get_game_state() to authenticated;
-- Question bank is appended below before COMMIT.

insert into public.weekly_questions values
(0,'Donner des comportements ou des traits humains à une chose, une idée ou un animal.',0,'[{"id":0,"name":"Personnification"},{"id":7,"name":"Anaphore"},{"id":15,"name":"Antonomase"},{"id":23,"name":"Épanadiplose"}]'::jsonb),
(1,'Représenter une idée abstraite par une figure concrète, souvent personnifiée.',1,'[{"id":1,"name":"Allégorie"},{"id":8,"name":"Parallélisme"},{"id":16,"name":"Épiphore"},{"id":24,"name":"Épitrochasme"}]'::jsonb),
(2,'Atténuer une réalité pénible ou choquante par une expression plus douce.',2,'[{"id":2,"name":"Euphémisme"},{"id":9,"name":"Oxymore"},{"id":17,"name":"Tapinose"},{"id":25,"name":"Hyperbate"}]'::jsonb),
(3,'Désigner une chose par une autre qui lui est liée : auteur et œuvre, contenant et contenu…',3,'[{"id":3,"name":"Métonymie"},{"id":10,"name":"Antiphrase"},{"id":18,"name":"Polysyndète"},{"id":26,"name":"Anadiplose"}]'::jsonb),
(4,'Désigner le tout par une partie, ou la partie par le tout.',4,'[{"id":4,"name":"Synecdoque"},{"id":11,"name":"Ellipse"},{"id":19,"name":"Asyndète"},{"id":27,"name":"Aposiopèse"}]'::jsonb),
(5,'Remplacer un mot par une expression qui le désigne.',5,'[{"id":5,"name":"Périphrase"},{"id":12,"name":"Zeugma"},{"id":20,"name":"Paradiastole"},{"id":28,"name":"Assonance"}]'::jsonb),
(6,'Dire moins pour suggérer davantage, souvent en niant le contraire.',6,'[{"id":6,"name":"Litote"},{"id":13,"name":"Paronomase"},{"id":21,"name":"Isotopie"},{"id":29,"name":"Allitération"}]'::jsonb),
(7,'Répéter un mot ou un groupe de mots au début de phrases ou de vers successifs.',7,'[{"id":7,"name":"Anaphore"},{"id":14,"name":"Prétérition"},{"id":22,"name":"Épanorthose"},{"id":30,"name":"Hypotypose"}]'::jsonb),
(8,'Répéter une même construction syntaxique.',8,'[{"id":8,"name":"Parallélisme"},{"id":15,"name":"Antonomase"},{"id":23,"name":"Épanadiplose"},{"id":31,"name":"Apostrophe"}]'::jsonb),
(9,'Associer deux termes de sens opposés dans un même groupe syntaxique.',9,'[{"id":0,"name":"Personnification"},{"id":9,"name":"Oxymore"},{"id":16,"name":"Épiphore"},{"id":24,"name":"Épitrochasme"}]'::jsonb),
(10,'Dire le contraire de ce que l’on pense, dans une intention ironique.',10,'[{"id":1,"name":"Allégorie"},{"id":10,"name":"Antiphrase"},{"id":17,"name":"Tapinose"},{"id":25,"name":"Hyperbate"}]'::jsonb),
(11,'Supprimer des mots que le contexte permet de comprendre.',11,'[{"id":2,"name":"Euphémisme"},{"id":11,"name":"Ellipse"},{"id":18,"name":"Polysyndète"},{"id":26,"name":"Anadiplose"}]'::jsonb),
(12,'Faire dépendre d’un même mot deux éléments de sens différents, souvent concret et abstrait.',12,'[{"id":3,"name":"Métonymie"},{"id":12,"name":"Zeugma"},{"id":19,"name":"Asyndète"},{"id":27,"name":"Aposiopèse"}]'::jsonb),
(13,'Rapprocher des mots dont les sons sont proches mais les sens différents.',13,'[{"id":4,"name":"Synecdoque"},{"id":13,"name":"Paronomase"},{"id":20,"name":"Paradiastole"},{"id":28,"name":"Assonance"}]'::jsonb),
(14,'Évoquer quelque chose tout en annonçant que l’on n’en parlera pas.',14,'[{"id":5,"name":"Périphrase"},{"id":14,"name":"Prétérition"},{"id":21,"name":"Isotopie"},{"id":29,"name":"Allitération"}]'::jsonb),
(15,'Employer un nom propre comme un nom commun, ou l’inverse.',15,'[{"id":6,"name":"Litote"},{"id":15,"name":"Antonomase"},{"id":22,"name":"Épanorthose"},{"id":30,"name":"Hypotypose"}]'::jsonb),
(16,'Répéter un mot ou un groupe de mots à la fin de phrases ou de vers successifs.',16,'[{"id":7,"name":"Anaphore"},{"id":16,"name":"Épiphore"},{"id":23,"name":"Épanadiplose"},{"id":31,"name":"Apostrophe"}]'::jsonb),
(17,'Rabaisser quelqu’un ou quelque chose par une expression dépréciative, souvent ironique.',17,'[{"id":0,"name":"Personnification"},{"id":8,"name":"Parallélisme"},{"id":17,"name":"Tapinose"},{"id":24,"name":"Épitrochasme"}]'::jsonb),
(18,'Répéter une conjonction devant les éléments d’une énumération.',18,'[{"id":1,"name":"Allégorie"},{"id":9,"name":"Oxymore"},{"id":18,"name":"Polysyndète"},{"id":25,"name":"Hyperbate"}]'::jsonb),
(19,'Supprimer les mots de liaison entre des éléments ou des propositions.',19,'[{"id":2,"name":"Euphémisme"},{"id":10,"name":"Antiphrase"},{"id":19,"name":"Asyndète"},{"id":26,"name":"Anadiplose"}]'::jsonb),
(20,'Selon ta fiche : aligner des segments de même longueur, de même construction et de même rythme.',20,'[{"id":3,"name":"Métonymie"},{"id":11,"name":"Ellipse"},{"id":20,"name":"Paradiastole"},{"id":27,"name":"Aposiopèse"}]'::jsonb),
(21,'Faire revenir des éléments de sens apparentés qui donnent une cohérence sémantique au texte.',21,'[{"id":4,"name":"Synecdoque"},{"id":12,"name":"Zeugma"},{"id":21,"name":"Isotopie"},{"id":28,"name":"Assonance"}]'::jsonb),
(22,'Revenir sur ses propres paroles pour les corriger, les nuancer ou les renforcer.',22,'[{"id":5,"name":"Périphrase"},{"id":13,"name":"Paronomase"},{"id":22,"name":"Épanorthose"},{"id":29,"name":"Allitération"}]'::jsonb),
(23,'Commencer et terminer une phrase ou une proposition par le même mot ou groupe de mots.',23,'[{"id":6,"name":"Litote"},{"id":14,"name":"Prétérition"},{"id":23,"name":"Épanadiplose"},{"id":30,"name":"Hypotypose"}]'::jsonb),
(24,'Accumuler des mots brefs et expressifs, généralement juxtaposés.',24,'[{"id":7,"name":"Anaphore"},{"id":15,"name":"Antonomase"},{"id":24,"name":"Épitrochasme"},{"id":31,"name":"Apostrophe"}]'::jsonb),
(25,'Ajouter un élément après une phrase qui semblait terminée.',25,'[{"id":0,"name":"Personnification"},{"id":8,"name":"Parallélisme"},{"id":16,"name":"Épiphore"},{"id":25,"name":"Hyperbate"}]'::jsonb),
(26,'Reprendre à l’ouverture d’un segment le mot ou groupe qui terminait le précédent.',26,'[{"id":1,"name":"Allégorie"},{"id":9,"name":"Oxymore"},{"id":17,"name":"Tapinose"},{"id":26,"name":"Anadiplose"}]'::jsonb),
(27,'Interrompre brusquement une phrase, notamment sous l’effet de l’émotion.',27,'[{"id":2,"name":"Euphémisme"},{"id":10,"name":"Antiphrase"},{"id":18,"name":"Polysyndète"},{"id":27,"name":"Aposiopèse"}]'::jsonb),
(28,'Répéter un même son de voyelle dans une phrase ou des vers.',28,'[{"id":3,"name":"Métonymie"},{"id":11,"name":"Ellipse"},{"id":19,"name":"Asyndète"},{"id":28,"name":"Assonance"}]'::jsonb),
(29,'Répéter un même son de consonne dans une phrase ou des vers.',29,'[{"id":4,"name":"Synecdoque"},{"id":12,"name":"Zeugma"},{"id":20,"name":"Paradiastole"},{"id":29,"name":"Allitération"}]'::jsonb),
(30,'Décrire une scène avec assez de vivacité pour donner l’impression de la voir.',30,'[{"id":5,"name":"Périphrase"},{"id":13,"name":"Paronomase"},{"id":21,"name":"Isotopie"},{"id":30,"name":"Hypotypose"}]'::jsonb),
(31,'S’adresser directement à une personne, une idée, une divinité ou un objet.',31,'[{"id":6,"name":"Litote"},{"id":14,"name":"Prétérition"},{"id":22,"name":"Épanorthose"},{"id":31,"name":"Apostrophe"}]'::jsonb)
on conflict(id) do update set prompt=excluded.prompt,correct_id=excluded.correct_id,options=excluded.options;
commit;
