# Figures en jeu

Jeu de révision des 32 figures de style du cours.

[Jouer](https://kriskarachorov.github.io/figures-en-jeu/)

## Jouer et progresser

- Entraînement expliqué, fiches mémo et contrôle blanc sur 20.
- Quête quotidienne de cinq figures différentes sans indice (+25 XP), renouvelée à minuit UTC.
- Combos, six badges, niveaux de 200 XP et titres de progression.
- Combat de nuances : identifier une figure puis justifier son mécanisme.
- Revanche : des exemples alternatifs pour les figures à revoir.
- Maîtrise : trois journées de réussite sans indice par figure. Aucune pénalité pour une journée manquée.
- Records de réussite, combo et contrôle blanc.
- Défi hebdomadaire commun, une note par compte. Classement facultatif par pseudo, sans bonus de vitesse. Un score partagé peut être retiré.
- Couleurs claires ou sombres selon l’appareil, animations réduites selon les préférences système, son désactivé par défaut.

Les manches terminées sont sauvegardées. Quitter une manche incomplète ne rapporte pas de récompense. Une bonne réponse rapporte 10 XP, ou 5 avec indice, jusqu’à deux réponses récompensées par figure et jour UTC. Un combo de cinq rapporte 5 XP ; un boss parfait, 10 ; une erreur corrigée en revanche, 5 supplémentaires. Ces bonus dépendent également des réponses encore récompensables. Les anciens points restent acquis.

Sans compte, les récompenses restent uniquement en mémoire pendant la visite. Les manches d’un compte en attente de sauvegarde restent dans le stockage de cet appareil et sont réessayées à la reconnexion. Les tentatives de sauvegarde sont idempotentes et ne transfèrent pas les résultats entre comptes.

## Configuration

Site statique publié depuis la racine de `main` par GitHub Pages. Aucun processus de compilation nécessaire.

Exécuter dans Supabase SQL Editor, dans cet ordre et une seule fois :

1. `supabase/migrations/001_progress.sql`
2. `supabase/migrations/002_gameplay.sql`

Site URL et Redirect URL : `https://kriskarachorov.github.io/figures-en-jeu/`.

`accounts.js` contient uniquement l’URL et la clé publique Supabase. Ne jamais ajouter de clé secrète. Le SDK officiel fourni dans `vendor/` possède sa licence. La configuration e-mail existante est conservée.

Les tentatives personnelles sont privées. Seuls le pseudo et le score hebdomadaire deviennent visibles lorsque leur propriétaire le choisit. Les réponses du défi sont notées côté serveur, avec une seule validation par compte et semaine. Ce jeu scolaire n’est pas un système anti-triche : le contenu pédagogique est public.

## Vérification

`npm install`, puis `npm test` (Node récent).

Les tests utilisent un vrai PostgreSQL embarqué (PGlite) pour les migrations, droits d’accès, limites de récompense, sauvegardes répétées et défis communs. Les tests DOM couvrent les manches, les boss à deux étapes, les badges, les 32 anneaux, les corrections différées, le mode invité, la reprise après interruption et l’isolation entre comptes avec un service simulé.

Ces tests ne remplacent pas une vérification visuelle dans le navigateur ni un parcours e-mail réel.

Le terme « paradiastole » conserve l’emploi de la fiche de cours, signalé dans le jeu comme étant à confirmer avec le professeur.

made by kristian karachorov
