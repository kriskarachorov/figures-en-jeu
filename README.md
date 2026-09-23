# Figures en jeu

Jeu de révision des 32 figures de style du cours.

[Jouer](https://kriskarachorov.github.io/figures-en-jeu/)

## Contrôle du jeudi 24 septembre 2026

Le mode reprend exclusivement les 24 figures des deux feuilles fournies. Il s’ouvre sur un **contrôle rédigé** : nom → définition et exemple personnel, ou exemple → nom et définition. Les formats sont tirés indépendamment, sans alternance imposée. Les réponses sont modifiables avant envoi, avec un brouillon par compte sur l’appareil. La correction OpenAI est déclenchée une fois à la remise de la copie, avec demi-points, remarques, note indicative sur 20 et XP validés côté serveur. [Activation et budget](supabase/WRITTEN_SETUP.md).

Les outils complémentaires restent disponibles :

- Quiz de 24 questions, avec 96 exemples (quatre par figure) et les 24 définitions.
- « Comprendre » : identifier la figure, puis choisir son mécanisme ; les deux étapes doivent être justes.
- Révision ciblée de 10 figures : priorité aux erreurs, réponses aidées et figures dues pour une nouvelle révision.
- Contrôle rédigé de 24 questions, sans indice ni correction avant la remise de la copie.
- Bilan « Mon niveau » sur les cinq dernières réponses par figure des sept derniers jours. Trois réussites sans indice sur deux questions différentes, dont une explication juste, et au moins 80 % de réussite donnent le statut « Solide ». Une figure revient le lendemain, ou après trois jours si elle est solide. Une erreur la remet immédiatement à revoir.

Les nouvelles séries terminées sont sauvegardées sur le compte Supabase et retrouvées sur les autres appareils. Le serveur vérifie les identifiants des questions et les réponses, calcule les XP et empêche qu’une nouvelle tentative d’envoi double les points. Une réussite rapporte 10 XP, 5 avec indice ou 15 en mode Comprendre. La limite de deux réussites récompensées par figure et jour est commune aux modes généraux et à la révision de jeudi. Le classement et les notifications de dépassement utilisent ces mêmes XP.

Le cache local permet de consulter le dernier bilan disponible hors ligne ; les séries en attente sont envoyées à la reconnexion. Les anciens scores locaux de la première version ne sont pas convertis en XP, car ils ne contenaient pas le détail nécessaire à une validation.

Les photos ne sont pas publiées. Les exemples ambigus ont été clarifiés ; les constructions de tmésis ont été vérifiées dans le [Dictionnaire de l’Académie française](https://www.cnrtl.fr/definition/academie8/tm%C3%A8se).

## Jouer et progresser

- Entraînement expliqué, fiches mémo et contrôle blanc sur 20.
- Quête quotidienne de cinq figures différentes sans indice (+25 XP), renouvelée à minuit, heure de Sofia, avec prise en compte de l’heure d’été. Le message de réussite disparaît automatiquement au changement de jour, y compris au retour après une mise en veille.
- Combos, six badges, niveaux de 200 XP et titres de progression.
- Combat de nuances : identifier une figure puis justifier son mécanisme.
- Revanche : des exemples alternatifs pour les figures à revoir.
- Maîtrise : trois journées de réussite sans indice par figure. Aucune pénalité pour une journée manquée.
- Records de réussite, combo et contrôle blanc.
- Défi hebdomadaire commun, une note par compte. Classement facultatif par pseudo, sans bonus de vitesse. Un score partagé peut être retiré.
- Surfaces neutres claires ou sombres selon l’appareil, accents violets et police système. Animations de réponse, combos et transitions ; réduction selon les préférences système. Audio réutilisé et réactivé après suspension, son désactivé par défaut.
- Notification de dépassement à la fin d’une manche ou d’un défi hebdomadaire, après sauvegarde des XP. Les égalités ne déclenchent pas de message.
- Classement du total XP des comptes, visible uniquement aux joueurs connectés. Les ex æquo ayant des XP partagent leur rang ; les comptes à 0 XP reçoivent des rangs distincts par ordre alphabétique du pseudo (sans distinction de majuscules). À pseudo identique, un ordre stable départage les comptes ; ta position reste affichée même hors du top 100. Le classement se met à jour toutes les 30 secondes pendant sa consultation, au retour dans l’onglet et après une sauvegarde de points.

Les manches terminées sont sauvegardées. Quitter une manche incomplète ne rapporte pas de récompense. Une bonne réponse rapporte 10 XP, ou 5 avec indice, jusqu’à deux réponses récompensées par figure et jour (heure de Sofia). Un combo de cinq rapporte 5 XP ; un boss parfait, 10 ; une erreur corrigée en revanche, 5 supplémentaires. Ces bonus dépendent également des réponses encore récompensables. Les anciens points restent acquis.

La connexion est obligatoire pour accéder aux quiz et aux fiches. La déconnexion verrouille le jeu et interrompt la manche en cours. Les anciennes manches invitées ne sont pas transférées vers un compte. Les manches terminées en attente de sauvegarde restent associées au compte d’origine sur cet appareil ; elles sont réessayées à la reconnexion, sans doublon de XP.

## Configuration

Site statique publié depuis la racine de `main` par GitHub Pages. Aucun processus de compilation nécessaire.

Exécuter dans Supabase SQL Editor, dans cet ordre et une seule fois :

1. `supabase/migrations/001_progress.sql`
2. `supabase/migrations/002_gameplay.sql`
3. `supabase/migrations/003_xp_leaderboard.sql`
4. `supabase/migrations/004_rank_messages.sql`
5. `supabase/migrations/005_thursday_learning.sql`
6. `supabase/migrations/006_daily_reset_and_content.sql`
7. `supabase/migrations/007_zero_xp_ranks.sql`
8. `supabase/migrations/008_written_exam.sql` (puis activer le correcteur suivant le guide ci-dessus)

Site URL et Redirect URL : `https://kriskarachorov.github.io/figures-en-jeu/`.

`accounts.js` contient uniquement l’URL et la clé publique Supabase. Ne jamais ajouter de clé secrète. Le SDK officiel fourni dans `vendor/` possède sa licence. La configuration e-mail existante est conservée.

Les tentatives personnelles et les e-mails sont privés. Le pseudo et le total XP des comptes sont visibles dans le classement réservé aux joueurs connectés. Le partage du score dans le classement du défi hebdomadaire reste facultatif. Les réponses du défi sont notées côté serveur, avec une seule validation par compte et semaine. Ce jeu scolaire n’est pas un système anti-triche : le contenu pédagogique est public.

## Vérification

`npm install`, puis `npm test` (Node récent).

Les tests utilisent un vrai PostgreSQL embarqué (PGlite) pour les migrations, droits d’accès, limites de récompense, sauvegardes répétées et défis communs. Les tests DOM couvrent les manches, les boss à deux étapes, les badges, les 32 anneaux, les corrections différées, le verrouillage sans connexion, la reprise après interruption et l’isolation entre comptes avec un service simulé.

Ces tests ne remplacent pas une vérification visuelle dans le navigateur ni un parcours e-mail réel.

Le terme « paradiastole » conserve l’emploi de la fiche de cours : un parallélisme de segments de même syntaxe, rythme et longueur.

made by kristian karachorov
