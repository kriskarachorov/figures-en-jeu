-- Thursday revision: server-validated questions, synced history, shared XP caps.
begin;
create table if not exists public.thursday_questions(id int primary key,figure_id int not null check(figure_id between 0 and 23),kind text not null,prompt text not null,explanation text not null);
alter table public.thursday_questions enable row level security;
revoke all on public.thursday_questions from public,anon,authenticated;
create or replace function public.submit_thursday_round(p_id uuid,p_mode text,p_answers jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();d date:=(now() at time zone 'UTC')::date;a jsonb;q public.thursday_questions;s int;reason int;hint bool;ok bool;canonical int;uses int;xp int:=0;streak int:=0;best int:=0;credited int:=0;normalized jsonb:='[]';prior public.game_rounds;fids int[]:='{}';quest bool:=false;
 mapping int[]:=array[32,9,33,2,26,24,34,25,14,27,10,5,30,13,35,36,37,23,38,12,39,40,41,22];
begin
 if u is null then raise exception 'Authentication required' using errcode='42501';end if;
 if p_id is null or p_mode is null or p_mode not in ('thursday_quiz','thursday_targeted','thursday_why','thursday_exam') or p_answers is null or jsonb_typeof(p_answers)<>'array' or jsonb_array_length(p_answers) not between 1 and 24 then raise exception 'Invalid revision round';end if;
 if p_mode in ('thursday_quiz','thursday_exam') and jsonb_array_length(p_answers)<>24 then raise exception '24 answers required';end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select * into prior from public.game_rounds where user_id=u and id=p_id;
 if found then
  if prior.mode<>p_mode or (select jsonb_agg(jsonb_build_object('questionId',x->'questionId','selectedId',x->'selectedId','reasonId',x->'reasonId','hinted',x->'hinted')) from jsonb_array_elements(prior.answers) x)<>p_answers then raise exception 'Round already saved with other answers';end if;
  return jsonb_build_object('earned',prior.earned,'replayed',true);
 end if;
 for a in select * from jsonb_array_elements(p_answers) loop
  select * into q from public.thursday_questions where id=(a->>'questionId')::int;
  if not found then raise exception 'Unknown question';end if;
  if q.figure_id=any(fids) then raise exception 'Repeated figure';end if;
  fids:=array_append(fids,q.figure_id);s:=(a->>'selectedId')::int;reason:=(a->>'reasonId')::int;hint:=(a->>'hinted')::boolean;
  if s is null or s not between 0 and 23 or hint is null or (reason is not null and reason not between 0 and 23) or (p_mode='thursday_exam' and hint) or (p_mode='thursday_why' and (q.kind<>'example' or reason is null)) then raise exception 'Invalid answer';end if;
  ok:=s=q.figure_id and (p_mode<>'thursday_why' or reason=q.figure_id);canonical:=mapping[q.figure_id+1];
  if ok and not hint then streak:=streak+1;best:=greatest(best,streak);else streak:=0;end if;
  if ok then
   select c.uses into uses from public.game_credits c where c.user_id=u and c.day=d and c.figure_id=canonical;
   if coalesce(uses,0)<2 then
    xp:=xp+case when hint then 5 when p_mode='thursday_why' then 15 else 10 end;credited:=credited+1;
    insert into public.game_credits values(u,d,canonical,1) on conflict(user_id,day,figure_id) do update set uses=public.game_credits.uses+1;
   end if;
  end if;
  normalized:=normalized||jsonb_build_array(jsonb_build_object('questionId',q.id,'figureId',q.figure_id,'canonicalId',canonical,'selectedId',s,'reasonId',reason,'hinted',hint,'correct',ok));
 end loop;
 if best>=5 and credited>=5 then xp:=xp+5;end if;
 if (select count(distinct figure_id) from (
  select figure_id from public.figure_attempts where user_id=u and correct and not used_hint and (answered_at at time zone 'UTC')::date=d
  union all select (item->>'canonicalId')::int from public.game_rounds r cross join lateral jsonb_array_elements(r.answers) item where r.user_id=u and r.mode like 'thursday_%' and (r.completed_at at time zone 'UTC')::date=d and (item->>'correct')::boolean and not (item->>'hinted')::boolean
  union all select (item->>'canonicalId')::int from jsonb_array_elements(normalized) item where (item->>'correct')::boolean and not (item->>'hinted')::boolean
 ) today)>=5 then
  insert into public.game_quests values(u,d) on conflict do nothing;quest:=found;if quest then xp:=xp+25;end if;
 end if;
 insert into public.game_rounds(user_id,id,mode,answers,earned,best_combo,comeback) values(u,p_id,p_mode,normalized,xp,best,0);
 return jsonb_build_object('earned',xp,'best_combo',best,'quest',quest,'replayed',false);
end $$;
revoke all on function public.submit_thursday_round(uuid,text,jsonb) from public,anon;
grant execute on function public.submit_thursday_round(uuid,text,jsonb) to authenticated;
create or replace function public.get_thursday_progress() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('rounds',coalesce((select jsonb_agg(jsonb_build_object('id',id,'mode',mode,'answers',answers,'earned',earned,'completed_at',completed_at) order by completed_at) from public.game_rounds where user_id=auth.uid() and mode like 'thursday_%'),'[]'::jsonb));
$$;
revoke all on function public.get_thursday_progress() from public,anon;
grant execute on function public.get_thursday_progress() to authenticated;

insert into public.thursday_questions values
(99,0,'definition','Rapprochement de deux idées opposées dans une même phrase.','Rapprochement de deux idées opposées dans une même phrase.'),
(0,0,'example','Je vis, je meurs.','Les deux propositions opposent la vie et la mort.'),
(1,0,'example','Il rit le jour et pleure la nuit.','Deux idées contraires sont réparties dans deux segments.'),
(2,0,'example','Il possède tout et ne désire rien.','« Tout » et « rien » opposent deux idées dans des segments distincts.'),
(3,0,'example','Elle promet la paix, il prépare la guerre.','La paix et la guerre sont mises en opposition dans deux propositions.'),
(199,1,'definition','Alliance de deux mots contraires dans un même groupe de mots.','Alliance de deux mots contraires dans un même groupe de mots.'),
(100,1,'example','Un silence assourdissant.','« Silence » et « assourdissant » sont opposés et réunis dans le même groupe.'),
(101,1,'example','Cette obscure clarté.','Les termes contraires « obscure » et « clarté » sont associés directement.'),
(102,1,'example','Une douce violence.','Deux termes contraires sont réunis dans le même groupe.'),
(103,1,'example','Une joyeuse tristesse.','La joie et la tristesse sont directement associées.'),
(299,2,'definition','Exagération volontaire.','Exagération volontaire.'),
(200,2,'example','Je meurs de faim.','La faim est exagérée : le locuteur ne meurt pas réellement.'),
(201,2,'example','Je t’ai appelé mille fois !','Le nombre d’appels est volontairement amplifié.'),
(202,2,'example','Ce sac pèse une tonne !','Le poids réel du sac est fortement exagéré.'),
(203,2,'example','J’ai une montagne de devoirs.','La quantité de devoirs est amplifiée par l’image de la montagne.'),
(399,3,'definition','Atténuation d’une réalité brutale ou choquante.','Atténuation d’une réalité brutale ou choquante.'),
(300,3,'example','Il nous a quittés, dit-elle pour annoncer son décès.','« Nous a quittés » adoucit l’annonce de la mort.'),
(301,3,'example','Son entreprise le remercie : il vient d’être licencié.','« Remercier » atténue la réalité du licenciement.'),
(302,3,'example','Il s’est éteint à quatre-vingts ans.','« S’éteindre » adoucit l’annonce de la mort.'),
(303,3,'example','Des personnes sans domicile vivent ici.','Une formulation moins brutale évoque la situation de personnes vivant à la rue.'),
(499,4,'definition','Reprise du dernier mot d’une phrase au début de la suivante.','Reprise du dernier mot d’une phrase au début de la suivante.'),
(400,4,'example','Il avait peur. Peur de l’inconnu.','« Peur » termine le premier segment et commence le suivant.'),
(401,4,'example','Il cherche le bonheur. Le bonheur lui échappe.','La fin d’une phrase est reprise au début de la suivante.'),
(402,4,'example','La peur mène à la colère. La colère mène à la violence.','« La colère » relie la fin de la première phrase au début de la suivante.'),
(403,4,'example','Il lui reste un espoir. Un espoir minuscule.','Le groupe final devient l’ouverture du segment suivant.'),
(599,5,'definition','Accumulation de mots courts et frappants, souvent sans verbes.','Accumulation de mots courts et frappants, souvent sans verbes.'),
(500,5,'example','Vite, fort, droit.','Les mots brefs et juxtaposés produisent un rythme rapide.'),
(501,5,'example','Frappe, saigne, hurle.','Les verbes courts s’accumulent avec un effet frappant.'),
(502,5,'example','Du bruit, des cris, des coups.','Des mots courts et frappants s’accumulent rapidement.'),
(503,5,'example','Va, cours, vole !','La suite de verbes brefs donne un rythme précipité.'),
(699,6,'definition','Répétition d’une même terminaison sonore dans plusieurs mots proches.','Répétition d’une même terminaison sonore dans plusieurs mots proches.'),
(600,6,'example','Il avance lentement, prudemment, silencieusement.','Les trois mots ont la même terminaison sonore en « -ment ».'),
(601,6,'example','Une décision, une révision, une conclusion.','Les mots se terminent par le même son « -sion ».'),
(602,6,'example','La lenteur, la douceur, la chaleur du soir.','Les noms ont la même terminaison sonore en « -eur ».'),
(603,6,'example','Un récit charmant, touchant, troublant.','Les adjectifs proches se terminent par le son « -ant ».'),
(799,7,'definition','Ajout d’un mot ou d’un groupe après la fin logique de la phrase.','Ajout d’un mot ou d’un groupe après la fin logique de la phrase.'),
(700,7,'example','Tout le monde était parti. Même lui.','« Même lui » est ajouté après une phrase déjà complète.'),
(701,7,'example','Je l’aime, cette ville. Tellement.','« Tellement » prolonge un énoncé qui semblait terminé.'),
(702,7,'example','Il avait tout prévu. Sauf elle.','L’ajout « Sauf elle » arrive après une phrase grammaticalement complète.'),
(703,7,'example','La salle était vide. De spectateurs, du moins.','Une précision prolonge après coup une phrase qui semblait finie.'),
(899,8,'definition','Dire qu’on ne va pas dire quelque chose, tout en le disant.','Dire qu’on ne va pas dire quelque chose, tout en le disant.'),
(800,8,'example','Je ne vous dirai pas qu’il a triché.','Le locuteur révèle la tricherie en annonçant qu’il ne la révélera pas.'),
(801,8,'example','Inutile de rappeler qu’il a échoué lamentablement.','Le fait de prétendre ne pas rappeler l’échec le rappelle quand même.'),
(802,8,'example','Je passerai sous silence ses trois absences.','Le locuteur mentionne les absences en prétendant les taire.'),
(803,8,'example','Sans parler de son arrogance, qui est insupportable.','La formule annonce ne pas parler d’un trait, puis le commente.'),
(999,9,'definition','Rupture ou suspension de phrase traduisant une émotion ou une hésitation.','Rupture ou suspension de phrase traduisant une émotion ou une hésitation.'),
(900,9,'example','Si jamais tu fais ça, je…','La menace est interrompue avant d’être achevée.'),
(901,9,'example','Je vais te… mais non, tu ne comprends rien.','La phrase se brise et repart sur une autre idée.'),
(902,9,'example','Toi, ici ? Mais je croyais que…','La phrase reste inachevée sous l’effet de la surprise.'),
(903,9,'example','Si seulement j’avais… Enfin, il est trop tard.','L’énoncé est suspendu puis abandonné.'),
(1099,10,'definition','Dire le contraire de ce que l’on pense, souvent ironiquement.','Dire le contraire de ce que l’on pense, souvent ironiquement.'),
(1000,10,'example','Bravo ! Tu as encore tout raté.','Le compliment apparent exprime en réalité un reproche.'),
(1001,10,'example','Quel temps magnifique ! dit-il sous une pluie glaciale.','Le contexte montre que le locuteur pense le contraire de ses mots.'),
(1002,10,'example','Quelle ponctualité ! Tu arrives une heure en retard.','Le reproche prend la forme ironique d’un compliment contraire à la réalité.'),
(1003,10,'example','Très malin : tu as enfermé les clés dans la voiture.','« Très malin » exprime ici un jugement opposé.'),
(1199,11,'definition','Remplacer un mot par une expression qui le désigne.','Remplacer un mot par une expression qui le désigne.'),
(1100,11,'example','Le roi des animaux dort à l’ombre.','« Le roi des animaux » désigne le lion par une expression.'),
(1101,11,'example','La capitale de la France accueille les visiteurs.','L’expression désigne Paris sans employer son nom.'),
(1102,11,'example','La Ville Lumière attire les touristes.','Une expression désigne Paris à la place de son nom.'),
(1103,11,'example','Le septième art célèbre ses acteurs.','« Le septième art » désigne le cinéma.'),
(1299,12,'definition','Description vivante et imagée d’une scène, comme si on y assistait.','Description vivante et imagée d’une scène, comme si on y assistait.'),
(1200,12,'example','Le sang coulait, les corps jonchaient le sol, un soldat rampait vers la porte.','Les détails concrets et les actions rendent la scène presque visible.'),
(1201,12,'example','La porte claque, une tasse éclate, le café se répand ; une main tremblante ramasse les morceaux.','La succession d’actions et de détails donne l’impression d’assister à la scène.'),
(1202,12,'example','Le train freine ; des étincelles jaillissent. Sur le quai, une valise bascule et des voyageurs reculent.','Les actions et les détails visuels font assister à la scène.'),
(1203,12,'example','La flamme lèche le rideau, la fumée envahit la pièce, un enfant tousse près de la fenêtre.','La description concrète et animée rend la scène présente au lecteur.'),
(1399,13,'definition','Rapprochement de mots aux sons proches mais aux sens différents.','Rapprochement de mots aux sons proches mais aux sens différents.'),
(1300,13,'example','Qui se ressemble s’assemble.','« Ressemble » et « assemble » ont des sons proches et des sens différents.'),
(1301,13,'example','Il hésite entre le poison et le poisson.','Les deux mots se ressemblent à l’oreille mais ne désignent pas la même chose.'),
(1302,13,'example','Il préfère les mots aux maux.','Les sons se ressemblent, mais les sens diffèrent : paroles et souffrances.'),
(1303,13,'example','Le percepteur attend le précepteur.','Les deux noms sont proches à l’oreille et désignent des personnes différentes.'),
(1499,14,'definition','Hyperbole poussée à l’impossible : une exagération irréalisable.','Hyperbole poussée à l’impossible : une exagération irréalisable.'),
(1400,14,'example','Quand les poules auront des dents.','L’image exprime une impossibilité, au-delà de la simple amplification.'),
(1401,14,'example','Je partirai quand les pierres se mettront à parler.','L’événement annoncé est impossible.'),
(1402,14,'example','Je te croirai quand le soleil se lèvera à l’ouest.','L’image annonce un événement impossible dans le fonctionnement habituel du monde.'),
(1403,14,'example','Je finirai quand les poissons grimperont aux arbres.','L’exagération repose sur une impossibilité.'),
(1599,15,'definition','Répétition d’un même mot avec un sens différent.','Répétition d’un même mot avec un sens différent.'),
(1500,15,'example','Mon avocat achète un avocat au marché.','Le même mot désigne d’abord le professionnel du droit, puis le fruit.'),
(1501,15,'example','Cette règle de grammaire n’est pas la règle qui mesure ma feuille.','Le même mot est répété : d’abord une prescription, puis un instrument.'),
(1502,15,'example','Le facteur apporte une lettre ; ce retard est un facteur de stress.','« Facteur » désigne d’abord un métier, puis une cause.'),
(1503,15,'example','Le courant est fort, mais je ne suis pas au courant.','« Courant » désigne d’abord un mouvement d’eau, puis le fait d’être informé.'),
(1699,16,'definition','Attribution d’un mot à un autre que celui qu’il qualifie logiquement.','Attribution d’un mot à un autre que celui qu’il qualifie logiquement.'),
(1600,16,'example','Un vieillard en or avec une montre fatiguée.','Les qualifications sont déplacées : c’est normalement la montre qui est en or et le vieillard qui est fatigué.'),
(1601,16,'example','Le voyageur parcourait une route fatiguée.','« Fatiguée » qualifie grammaticalement la route, alors que la fatigue concerne le voyageur.'),
(1602,16,'example','Il traînait ses pas fatigués jusqu’au lit.','La fatigue de la personne est transférée aux pas.'),
(1603,16,'example','Elle s’assit sur un banc désespéré.','Le désespoir de la personne est attribué au banc.'),
(1799,17,'definition','Reprise, à la fin d’une phrase, du mot qui la commence.','Reprise, à la fin d’une phrase, du mot qui la commence.'),
(1700,17,'example','L’homme est un loup pour l’homme.','« L’homme » se trouve au début et à la fin du même énoncé.'),
(1701,17,'example','Seul, il attendait dans la salle, seul.','Le même mot encadre une seule phrase.'),
(1702,17,'example','La nuit recouvre tout, la nuit.','Le même groupe ouvre et ferme la phrase.'),
(1703,17,'example','Demain, nous réglerons cette affaire, demain.','Le mot initial revient à la fin du même énoncé.'),
(1899,18,'definition','Répétition d’un mot sous plusieurs formes grammaticales.','Répétition d’un mot sous plusieurs formes grammaticales.'),
(1800,18,'example','Je vis, tu vivras, nous avons vécu.','Le verbe vivre revient sous plusieurs formes conjuguées.'),
(1801,18,'example','Aimer, j’aime ; aimé, je le serai peut-être.','Le même verbe apparaît à l’infinitif, conjugué et au participe passé.'),
(1802,18,'example','Je sais que tu savais ce que nous saurons demain.','Le verbe savoir revient au présent, à l’imparfait et au futur.'),
(1803,18,'example','Il veut ce qu’il voulait et voudra toujours.','Le même verbe revient sous plusieurs formes conjuguées.'),
(1999,19,'definition','Coordination de termes disparates, souvent concrets et abstraits.','Coordination de termes disparates, souvent concrets et abstraits.'),
(1900,19,'example','Il a perdu sa montre et son sourire.','Un seul verbe relie un objet concret et un élément abstrait.'),
(1901,19,'example','Il prit du ventre et de l’importance.','« Prit » gouverne deux compléments de sens différents.'),
(1902,19,'example','Elle ouvrit la porte et son cœur.','Le même verbe relie un complément concret et un complément abstrait.'),
(1903,19,'example','Il quitta la ville et ses illusions.','« Quitta » gouverne deux éléments de plans différents.'),
(2099,20,'definition','Emploi d’un même mot à la fois au sens propre et au sens figuré.','Emploi d’un même mot à la fois au sens propre et au sens figuré.'),
(2000,20,'example','Cet homme est droit : sa posture comme sa conduite le montrent.','« Droit », employé une seule fois, désigne à la fois la posture physique et l’honnêteté.'),
(2001,20,'example','Elle est lumineuse : sa robe brille et son intelligence éclaire la discussion.','« Lumineuse » est compris à la fois au sens physique et au sens figuré.'),
(2002,20,'example','Son accueil est froid : le hall est glacial et son ton distant.','« Froid » prend simultanément un sens thermique et un sens affectif.'),
(2003,20,'example','Ce discours est lourd : le manuscrit pèse deux kilos et le propos ennuie tout le monde.','« Lourd » évoque à la fois le poids matériel et la lourdeur du style.'),
(2199,21,'definition','Croisement de termes selon un schéma ABBA.','Croisement de termes selon un schéma ABBA.'),
(2100,21,'example','Il faut manger pour vivre, et non vivre pour manger.','Manger / vivre devient vivre / manger : l’ordre est inversé.'),
(2101,21,'example','En échangeant un regard, un regard en échangeant.','Les mêmes groupes sont repris dans l’ordre inverse.'),
(2102,21,'example','Il travaille pour vivre, et ne vit pas pour travailler.','Travailler / vivre est repris dans l’ordre vivre / travailler.'),
(2103,21,'example','La force de l’amour et l’amour de la force.','L’ordre force / amour est inversé dans amour / force.'),
(2299,22,'definition','Séparation d’un mot composé par intercalation.','Séparation d’un mot composé par intercalation.'),
(2200,22,'example','Lors même que la pluie tomberait, nous sortirions.','Le mot « lorsque » est séparé par l’intercalation de « même ».'),
(2201,22,'example','Puis donc que vous le demandez, je répondrai.','Le mot « puisque » est séparé par l’intercalation de « donc ».'),
(2202,22,'example','Lors même que tu hésiterais, je resterais.','« Même » sépare les deux éléments de « lorsque » : lors et que.'),
(2203,22,'example','Puis donc que tu insistes, entrons.','« Donc » s’intercale entre les deux éléments de « puisque » : puis et que.'),
(2399,23,'definition','Rectification ou correction d’un propos pour le renforcer.','Rectification ou correction d’un propos pour le renforcer.'),
(2300,23,'example','C’est un héros, non, un dieu !','Le locuteur corrige « héros » par le terme plus fort « dieu ».'),
(2301,23,'example','Il est intelligent, que dis-je, génial !','Le second qualificatif corrige et renforce le premier.'),
(2302,23,'example','C’est utile, non, indispensable.','Le premier jugement est corrigé par un terme plus fort.'),
(2303,23,'example','Il marche, ou plutôt il court.','Le locuteur revient sur son premier verbe pour le rectifier.')
on conflict(id) do update set figure_id=excluded.figure_id,kind=excluded.kind,prompt=excluded.prompt,explanation=excluded.explanation;
commit;
