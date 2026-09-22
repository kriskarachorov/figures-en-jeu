# Figures en jeu

Jeu de révision des 32 figures de style du cours.

[Jouer](https://kriskarachorov.github.io/figures-en-jeu/)

## Contrôle du jeudi 24 septembre 2026

L’onglet « Contrôle jeudi » remplace le contrôle blanc dans la navigation. Il reprend exclusivement les 24 figures des deux feuilles fournies : quiz de 24 questions mêlant définitions et exemples, corrections immédiates, indices, reprise des erreurs et fiches dédiées. Les réponses proposées appartiennent toutes à ces mêmes 24 figures.

La tmésis est interrogée par sa définition ; ses exemples particuliers restent consultables dans les fiches. Des exemples plus explicites sont utilisés lorsque ceux de la feuille peuvent illustrer plusieurs procédés. Les photos elles-mêmes ne sont pas publiées.

Le score, le meilleur résultat et les figures à revoir sont conservés sur cet appareil, séparément pour chaque compte, sans modifier les XP ou le classement général. Les autres modes conservent leur programme d’origine.

## Jouer et progresser

- Entraînement expliqué, fiches mémo et contrôle blanc sur 20.
- Quête quotidienne de cinq figures différentes sans indice (+25 XP), renouvelée à minuit UTC.
- Combos, six badges, niveaux de 200 XP et titres de progression.
- Combat de nuances : identifier une figure puis justifier son mécanisme.
- Revanche : des exemples alternatifs pour les figures à revoir.
- Maîtrise : trois journées de réussite sans indice par figure. Aucune pénalité pour une journée manquée.
- Records de réussite, combo et contrôle blanc.
- Défi hebdomadaire commun, une note par compte. Classement facultatif par pseudo, sans bonus de vitesse. Un score partagé peut être retiré.
- Surfaces neutres claires ou sombres selon l’appareil, accents violets et police système. Animations de réponse, combos et transitions ; réduction selon les préférences système. Audio réutilisé et réactivé après suspension, son désactivé par défaut.
- Notification de dépassement à la fin d’une manche ou d’un défi hebdomadaire, après sauvegarde des XP. Les égalités ne déclenchent pas de message.
- Classement du total XP des comptes, visible uniquement aux joueurs connectés. Les ex æquo partagent leur rang ; ta position reste affichée même hors du top 100.

Les manches terminées sont sauvegardées. Quitter une manche incomplète ne rapporte pas de récompense. Une bonne réponse rapporte 10 XP, ou 5 avec indice, jusqu’à deux réponses récompensées par figure et jour UTC. Un combo de cinq rapporte 5 XP ; un boss parfait, 10 ; une erreur corrigée en revanche, 5 supplémentaires. Ces bonus dépendent également des réponses encore récompensables. Les anciens points restent acquis.

La connexion est obligatoire pour accéder aux quiz et aux fiches. La déconnexion verrouille le jeu et interrompt la manche en cours. Les anciennes manches invitées ne sont pas transférées vers un compte. Les manches terminées en attente de sauvegarde restent associées au compte d’origine sur cet appareil ; elles sont réessayées à la reconnexion, sans doublon de XP.

## Configuration

Site statique publié depuis la racine de `main` par GitHub Pages. Aucun processus de compilation nécessaire.

Exécuter dans Supabase SQL Editor, dans cet ordre et une seule fois :

1. `supabase/migrations/001_progress.sql`
2. `supabase/migrations/002_gameplay.sql`
3. `supabase/migrations/003_xp_leaderboard.sql`
4. `supabase/migrations/004_rank_messages.sql`

Site URL et Redirect URL : `https://kriskarachorov.github.io/figures-en-jeu/`.

`accounts.js` contient uniquement l’URL et la clé publique Supabase. Ne jamais ajouter de clé secrète. Le SDK officiel fourni dans `vendor/` possède sa licence. La configuration e-mail existante est conservée.

Les tentatives personnelles et les e-mails sont privés. Le pseudo et le total XP des comptes sont visibles dans le classement réservé aux joueurs connectés. Le partage du score dans le classement du défi hebdomadaire reste facultatif. Les réponses du défi sont notées côté serveur, avec une seule validation par compte et semaine. Ce jeu scolaire n’est pas un système anti-triche : le contenu pédagogique est public.

## Vérification

`npm install`, puis `npm test` (Node récent).

Les tests utilisent un vrai PostgreSQL embarqué (PGlite) pour les migrations, droits d’accès, limites de récompense, sauvegardes répétées et défis communs. Les tests DOM couvrent les manches, les boss à deux étapes, les badges, les 32 anneaux, les corrections différées, le verrouillage sans connexion, la reprise après interruption et l’isolation entre comptes avec un service simulé.

Ces tests ne remplacent pas une vérification visuelle dans le navigateur ni un parcours e-mail réel.

Le terme « paradiastole » conserve l’emploi de la fiche de cours, signalé dans le jeu comme étant à confirmer avec le professeur.

made by kristian karachorov
