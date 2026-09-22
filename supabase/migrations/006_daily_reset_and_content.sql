-- Corrected content and one shared daily boundary: midnight Europe/Sofia.
begin;
do $update$
declare body text;
begin
 body:=pg_get_functiondef('public.submit_game_round(uuid,text,jsonb)'::regprocedure);
 body:=replace(body,'at time zone ''UTC''','at time zone ''Europe/Sofia''');
 body:=replace(body,
 '(select count(distinct figure_id) from public.figure_attempts where user_id=u and correct and not used_hint and (answered_at at time zone ''Europe/Sofia'')::date=d)',
 '(select count(distinct figure_id) from (select figure_id from public.figure_attempts where user_id=u and correct and not used_hint and (answered_at at time zone ''Europe/Sofia'')::date=d union all select (item->>''canonicalId'')::int from public.game_rounds revision cross join lateral jsonb_array_elements(revision.answers) item where revision.user_id=u and revision.mode like ''thursday_%'' and (revision.completed_at at time zone ''Europe/Sofia'')::date=d and (item->>''correct'')::boolean and not (item->>''hinted'')::boolean) today)');
 execute body;
 body:=pg_get_functiondef('public.submit_thursday_round(uuid,text,jsonb)'::regprocedure);
 execute replace(body,'at time zone ''UTC''','at time zone ''Europe/Sofia''');
end $update$;
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
(303,3,'example','Il traverse une période difficile, dit-on pour ne pas annoncer brutalement sa ruine.','La formule adoucit la réalité pénible de la ruine.'),
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
(700,7,'example','Voilà une belle demeure, et plaisante.','« Et plaisante » ajoute une qualification après une fin logique apparente, dans la même phrase.'),
(701,7,'example','La nuit était noire, et profonde.','L’adjectif « profonde » est ajouté après l’énoncé complet « La nuit était noire ».'),
(702,7,'example','Il n’avait qu’un mot à dire, un seul.','« Un seul » prolonge l’énoncé après sa fin logique et met l’unicité en relief.'),
(703,7,'example','Il est parti sans un mot, et pour toujours.','Le complément « et pour toujours » est ajouté dans la même phrase, après une fin apparente.'),
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
(2002,20,'example','Ce vêtement est cher, par son prix et par les souvenirs qu’il porte.','« Cher » exprime simultanément le prix élevé et la valeur affective.'),
(2003,20,'example','Ce livre est lourd : il pèse deux kilos et son style est difficile à lire.','« Lourd » caractérise à la fois le poids matériel du livre et la lourdeur de son style.'),
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
update public.weekly_questions set prompt='Donner des comportements ou des traits humains à une chose, une idée ou un animal.' where id=0;
update public.weekly_questions set prompt='Représenter une idée abstraite par une figure concrète, souvent personnifiée.' where id=1;
update public.weekly_questions set prompt='Atténuer une réalité pénible ou choquante par une expression plus douce.' where id=2;
update public.weekly_questions set prompt='Désigner une chose par une autre qui lui est liée : auteur et œuvre, contenant et contenu…' where id=3;
update public.weekly_questions set prompt='Désigner le tout par une partie, ou la partie par le tout.' where id=4;
update public.weekly_questions set prompt='Remplacer un mot par une expression qui le désigne.' where id=5;
update public.weekly_questions set prompt='Dire moins pour suggérer davantage, souvent en niant le contraire.' where id=6;
update public.weekly_questions set prompt='Répéter un mot ou un groupe de mots au début de phrases ou de vers successifs.' where id=7;
update public.weekly_questions set prompt='Répéter une même construction syntaxique.' where id=8;
update public.weekly_questions set prompt='Associer deux termes de sens opposés dans un même groupe syntaxique.' where id=9;
update public.weekly_questions set prompt='Dire le contraire de ce que l’on pense, dans une intention ironique.' where id=10;
update public.weekly_questions set prompt='Supprimer des mots que le contexte permet de comprendre.' where id=11;
update public.weekly_questions set prompt='Faire dépendre d’un même mot deux éléments de sens différents, souvent concret et abstrait.' where id=12;
update public.weekly_questions set prompt='Rapprocher des mots dont les sons sont proches mais les sens différents.' where id=13;
update public.weekly_questions set prompt='Évoquer quelque chose tout en annonçant que l’on n’en parlera pas.' where id=14;
update public.weekly_questions set prompt='Employer un nom propre comme un nom commun, ou l’inverse.' where id=15;
update public.weekly_questions set prompt='Répéter un mot ou un groupe de mots à la fin de phrases ou de vers successifs.' where id=16;
update public.weekly_questions set prompt='Rabaisser quelqu’un ou quelque chose par une expression dépréciative, souvent ironique.' where id=17;
update public.weekly_questions set prompt='Répéter une conjonction devant les éléments d’une énumération.' where id=18;
update public.weekly_questions set prompt='Supprimer les mots de liaison entre des éléments ou des propositions.' where id=19;
update public.weekly_questions set prompt='Aligner des segments de même syntaxe, de même rythme et de même longueur.' where id=20;
update public.weekly_questions set prompt='Faire revenir des éléments de sens apparentés qui donnent une cohérence sémantique au texte.' where id=21;
update public.weekly_questions set prompt='Revenir sur ses propres paroles pour les corriger, les nuancer ou les renforcer.' where id=22;
update public.weekly_questions set prompt='Commencer et terminer une phrase ou une proposition par le même mot ou groupe de mots.' where id=23;
update public.weekly_questions set prompt='Accumuler des mots brefs et expressifs, généralement juxtaposés.' where id=24;
update public.weekly_questions set prompt='Prolonger un énoncé qui semblait complet par un ajout mis en relief.' where id=25;
update public.weekly_questions set prompt='Reprendre à l’ouverture d’un segment le mot ou groupe qui terminait le précédent.' where id=26;
update public.weekly_questions set prompt='Interrompre brusquement une phrase, notamment sous l’effet de l’émotion.' where id=27;
update public.weekly_questions set prompt='Répéter un même son de voyelle dans une phrase ou des vers.' where id=28;
update public.weekly_questions set prompt='Répéter un même son de consonne dans une phrase ou des vers.' where id=29;
update public.weekly_questions set prompt='Décrire une scène avec assez de vivacité pour donner l’impression de la voir.' where id=30;
update public.weekly_questions set prompt='S’adresser directement à une personne, une idée, une divinité ou un objet.' where id=31;
commit;
