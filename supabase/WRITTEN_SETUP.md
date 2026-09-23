# Activer le contrôle rédigé pour jeudi

Le code est prêt et testé localement. La clé OpenAI, la migration 008 et la fonction Supabase restent à installer. L’ancien site reste en ligne jusqu’à cette activation.

## 1. Activer l’API OpenAI

Ouvre [la facturation API](https://platform.openai.com/settings/organization/billing/overview). Utilise le solde existant si tu en as un. Sinon, vérifie le montant total demandé, taxes comprises, avant tout paiement : le coût des corrections et le montant minimum de crédit à acheter sont deux choses différentes. Ne valide pas un paiement supérieur à ton budget de 5 €. Désactive les recharges automatiques.

Crée une clé dans [API keys](https://platform.openai.com/api-keys). Garde-la privée : ne la colle ni dans le chat, ni dans GitHub, ni dans le code du site.

Dans [ton projet Supabase](https://supabase.com/dashboard/project/jivcksyusroudenhmjxa), ouvre **Edge Functions → Secrets** et ajoute :

- Name : `OPENAI_API_KEY`
- Value : la clé que tu viens de créer.

Les autres secrets utilisés (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) sont fournis par Supabase à la fonction. Ils restent côté serveur.

## 2. Installer la mise à jour de la base

Dans **SQL Editor**, remplace entièrement le contenu par celui de [008_written_exam.sql](migrations/008_written_exam.sql), puis clique **Run**. Ne modifie pas les anciens scripts et ne copie pas seulement un extrait.

Cette mise à jour conserve les comptes et XP. Elle ajoute les copies privées, les notes, les limites et les récompenses vérifiées côté serveur.

## 3. Installer le correcteur

Dans **Edge Functions → Deploy a new function → Via Editor** :

1. Nomme la fonction exactement `grade-written`.
2. Remplace tout le contenu de `index.ts` par [le fichier du correcteur](functions/grade-written/index.ts). Ce fichier est autonome : aucun autre fichier à importer.
3. Déploie la fonction.
4. Dans les réglages de cette fonction, désactive **Verify JWT with legacy secret** / **Enforce JWT verification** si ce réglage est présent. Le correcteur vérifie lui-même chaque session auprès de Supabase Auth avant de réserver du budget ou d’appeler OpenAI. La clé publique seule ne permet pas de corriger une copie.

Signale ensuite « clé ajoutée, SQL réussi et fonction déployée ». La publication du site et un essai de correction réel restent à vérifier après cette étape.

## Coût prévu et limites

Chiffres communiqués le 23 septembre : **11 comptes, 3 860 XP, 72 parties, 672 réponses**. Les XP ne permettent pas de compter les réponses (bonus, erreurs et plafonds). Les 672 réponses représentent 28 copies de 24 questions.

Avec GPT-5.4 mini, à 6 000 tokens d’entrée et 3 000 de sortie par copie :

- 1 copie : 0,018 $.
- 28 copies : 0,504 $, environ 0,44 € hors taxes/frais.
- 110 copies (10 par compte) : 1,98 $, environ 1,73 € hors taxes/frais.

Ce sont des estimations, pas des mesures : longueur des réponses, correction et tentatives supplémentaires font varier le prix. Le modèle est fixé à `gpt-5.4-mini-2026-03-17` ; aucun modèle plus cher n’est utilisé en remplacement.

Le correcteur réserve une enveloppe conservatrice avant chaque appel, puis utilise les tokens réellement facturés pour libérer le reliquat. Une tentative dont le coût n’est pas connu conserve sa réservation. La consommation API de cette campagne est limitée à **4 $ au total**, et les nouveaux appels s’arrêtent **vendredi 25 septembre à 00:00, heure de Sofia**. Les copies déjà corrigées restent consultables. Le plafond couvre cette fonction et ce modèle aux tarifs vérifiés, pas les autres usages éventuels de la clé OpenAI, ni taxes ou frais bancaires.

Autres limites : 10 appels par compte et par jour, 200 pour le site par jour, deux tentatives maximum par copie, 600 caractères par définition/exemple, 80 pour le nom. Les nouvelles tentatives après erreur consomment aussi une place. Les soumissions simultanées et les limites sont gérées dans une transaction : deux onglets ne doublent pas les XP ni un appel déjà en cours.

## Correction et vérification

- Une figure différente par question, les mêmes 24 du cours. Choix aléatoire indépendant du format, sans alternance imposée ni quota 12/12.
- Nom donné → définition + exemple personnel. Exemple donné → nom + définition.
- Un point par champ, demi-points possibles, conversion sur 20. Les cas ambigus sont indiqués « À vérifier » et non comptés dans la note indicative.
- Une réponse entièrement juste rapporte 10 XP selon les plafonds partagés des autres modes. Le serveur calcule la note, les XP, les bonus et la quête ; le navigateur ne peut pas déclarer une correction comme validée.
- Les réponses et le cours sont transmis à OpenAI, sans ajouter l’e-mail, le pseudo ni l’identifiant du compte. `store: false`. Les brouillons restent sur l’appareil ; les corrections sont sauvegardées dans le compte.
- Les tests automatiques couvrent les copies privées, les limites, les répétitions, les erreurs réseau, l’interface et des réponses de modèle simulées. Ils ne mesurent pas encore la justesse pédagogique d’un appel réel : après activation, essayer une définition juste reformulée, un nom mal orthographié, un exemple personnel et une réponse incorrecte.

Sources : [tarifs et modèle OpenAI](https://developers.openai.com/api/docs/models/gpt-5.4-mini), [clé API côté serveur](https://developers.openai.com/api/reference/overview), [déploiement Supabase depuis le tableau de bord](https://supabase.com/docs/guides/functions/quickstart-dashboard), [secrets Supabase](https://supabase.com/docs/guides/functions/secrets). Conversion indicative au taux BCE du 22 septembre : 1 € = 1,1463 $.
