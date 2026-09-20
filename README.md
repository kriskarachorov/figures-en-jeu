# Figures en jeu

Jeu de révision en français : 32 figures de style, entraînement, contrôle blanc et fiches mémo.

Jouer : https://kriskarachorov.github.io/figures-en-jeu/

## Comptes et progression

Les comptes e-mail et mot de passe utilisent Supabase Auth. Les comptes connectés enregistrent leurs réponses et retrouvent leurs points et leur progression sur plusieurs appareils. Le jeu reste accessible sans compte, sans sauvegarde des réponses invitées.

- Bonne réponse : 10 points ; avec indice : 5 ; erreur : 0.
- Les résultats d’un contrôle sont envoyés à la fin. Quitter un contrôle incomplet ne rapporte pas de points.
- Une réponse en attente conserve son identifiant lors d’une nouvelle tentative de sauvegarde, pour éviter de compter deux fois les points.
- Les résultats sont privés grâce aux règles d’accès de la base. Il ne s’agit pas d’un classement compétitif protégé contre la triche.
- Les réponses en attente et la session de connexion sont conservées sur l’appareil. Les mots de passe sont traités uniquement par Supabase Auth.

## Configuration

Le schéma est dans `supabase/migrations/001_progress.sql`. La clé publique du projet peut être présente dans `accounts.js` ; aucune clé secrète ne doit être ajoutée au dépôt. Le client officiel Supabase JS 2.116.0 est fourni dans `vendor/`, avec sa licence.

Site URL et Redirect URL : `https://kriskarachorov.github.io/figures-en-jeu/`.

Avant d’ouvrir les inscriptions à des amis, configurer un serveur SMTP dans Supabase Authentication. Le service e-mail par défaut est limité et ne convient pas aux inscriptions de personnes hors de l’équipe du projet. Voir https://supabase.com/docs/guides/auth/auth-smtp .

## Vérification

Le schéma a été testé dans PostgreSQL embarqué (PGlite) avec deux utilisateurs distincts : accès privé, interdiction des écritures directes, refus des visiteurs non connectés, points 10/5/0 et sauvegardes répétées. Des tests DOM avec un service simulé ont vérifié les erreurs de connexion, le mode invité, les reprises après interruption, le changement de compte et le contrôle blanc. Le refus de lecture anonyme a également été vérifié sur le projet Supabase. Les parcours e-mail réels attendent la configuration SMTP.

Le terme « paradiastole » est repris de la fiche de cours avec une précision dans le jeu : cet emploi est à confirmer avec le professeur.

made by kristian karachorov
