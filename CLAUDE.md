# marineongoing : mes apps perso (Life, Study, Work)

Ce fichier présente le projet à Claude Code. Lis-le avant toute modification.

## Qui je suis et comment me parler

- Je m'appelle Marine. Je ne suis pas développeuse : explique simplement, en français, sans jargon.
- Tous les textes visibles dans les apps sont en français (tutoiement), sans emoji.
- Avant de modifier, dis-moi en une ou deux phrases ce que tu vas changer. Après, résume ce qui a changé et comment le vérifier.
- Demande toujours mon accord avant de publier (git push) ou de modifier la base Supabase.

## Organisation du site

Site statique publié par GitHub Pages sur https://marineongoing.github.io (branche `main`). Pas de build, pas de framework : chaque app est un seul fichier HTML (CSS et JS inclus).

```
index.html              page de lancement : work, life, study (+ réglages icônes / fond / flou, gardés en localStorage)
manifest.webmanifest    manifest de la page de lancement
sw.js                   « kill switch » : désinstalle l'ancien service worker qui contrôlait tout le site
icon-*.png              icônes de la page de lancement
life/                   app Life (ex « Mon quotidien ») : accueil, Health, Habits, Finance, Career, Goals, Journal, Gestion
study/                  app Study (BTS NDRC à l'INSEEC) : cours, devoirs, évaluations, révisions, alternance
vie/                    ancienne adresse : redirige vers /life/ et désinstalle son ancien service worker
supabase/migrations/    scripts SQL de la base (à appliquer dans l'ordre)
```

Work (dashboard d'alternance OTA & ventes flash chez Pierre & Vacances) est encore un artefact Claude :
https://claude.ai/artifact/MdVHPkN3pLHnB1bJggHRQi. Le rond « work » de la page de lancement l'ouvre dans un nouvel onglet. À migrer plus tard vers `work/` sur Supabase.

## Règles à respecter à chaque modification

1. **Ne modifie que les fichiers concernés**, au bon endroit : la page de lancement est `index.html` à la racine, Life est `life/index.html`, Study est `study/index.html`. Ne copie jamais le fichier d'une app à la racine.
2. **Service worker** : à chaque modification d'une app, augmente le numéro de cache dans son `sw.js`
   (`life/sw.js` : `mon-quotidien-vNN`, `study/sw.js` : `bts-ndrc-vNN`). Sinon l'iPhone garde l'ancienne version.
   Un service worker ne doit supprimer que les caches de son propre préfixe.
3. **Mobile et ordinateur** : chaque changement doit fonctionner sur iPhone (largeur 390 px) et sur ordinateur. Vérifie les deux.
4. **Teste en local avant de publier** : lance `python3 -m http.server 8000` à la racine, ouvre http://localhost:8000, vérifie la page modifiée et la console (aucune erreur).
5. **Ne perds jamais de données** : Life garde une copie locale (localStorage `vie2-cache`) et renvoie à Supabase tout ce qui n'y est pas encore. Ne casse pas ce mécanisme (`loadAll`, `saveItem`, `patch`, liste `dead` des éléments supprimés).
6. **Publication** : un seul commit par modification, message en français clair (ex. « Life : aura plus grande sur mobile »), puis `git push` après mon accord. GitHub Pages republie en 1 à 2 minutes.
7. **Base de données** : toute modification de la base passe par un nouveau fichier `supabase/migrations/NNN_description.sql`, idempotent (`create table if not exists`, `create or replace function`…), jamais de `drop table` ou de suppression de données sans me le demander explicitement.

## Sécurité (le dépôt est PUBLIC)

- Tout ce qui est poussé sur GitHub est visible par tout le monde.
- La clé « publishable » Supabase (`sb_publishable_…`) peut rester dans les fichiers HTML : elle est faite pour ça, la sécurité vient des règles RLS.
- Ne mets JAMAIS dans le dépôt : la clé `service_role`, un mot de passe, un jeton d'accès Supabase ou GitHub, ma clé privée du raccourci Santé, ni mes données personnelles (budget, adresse e-mail, santé).

## Supabase

Projet : `https://hfspexqbzmomrntlaqpn.supabase.co` (partagé par Life et Study, même connexion e-mail + mot de passe, session partagée car même origine).

Tables (toutes avec RLS : chaque utilisatrice ne voit que ses lignes, `user_id = auth.uid()`) :

- `docs` (Study) : `user_id`, `id`, `data jsonb`, `updated_at`. Ne pas modifier sa structure.
- `vie_days` (Life) : une ligne par jour. `data` contient notamment `moods` (liste de 1 à 5), `mood` (compatibilité), `tags`, `note`, `water`, `steps`, `sleep`, `sport` [{type,min,int}], `flow`, `sym`, `doneX`, `src` (origine « sante » ou « app »), `journal` (page du Journal), `journalRaw` (texte d'avant la mise au propre), `journalRecos` (recos de Claude sur la page), `habits` (identifiants des habitudes cochées à la main ce jour-là).
- `vie_items` (Life) : `id`, `kind`, `data`. kinds : `todo`, `exp` (dépense variable), `fix` (dépense fixe, avec `from`/`to`/`months`), `inc` (revenu, `rec` = « Chaque mois » ou « Ponctuel »), `event`, `cert`, `contact`, `goal` (avec `steps`), `habit` (`name`, `link` = donnée de l'app qui la coche toute seule ou « Moi, à la main », `target` facultatif, `from` = date de création).
- `vie_prefs` (Life) : réglages (prénom, profil, objectifs, épargne `savings`, ajustements du reste à vivre `rav`, recos de Claude…).
- `vie_tokens` (Life) : empreinte SHA-256 de la clé privée du raccourci Santé.

Fonctions :
- `vie_save(p_day, p_patch)` : fusionne un patch dans la journée (appelée par Life).
- `vie_import(p_token, p_day, p_steps, p_sleep, p_flow)` : appelée par le raccourci iPhone, vérifie la clé, accepte le sommeil en heures, minutes ou secondes.
- Edge Function `claude` : relaie les appels à l'API Claude pour les recos (Study et Life) et pour le Journal de Life (mise au propre, recos). Elle a besoin de deux secrets Supabase nommés `ALLOWED_EMAIL` et `ANTHROPIC_API_KEY` ; sans eux, elle répond « not_allowed ». Réponses limitées à 4000 tokens.

## Design (identique sur la page de lancement, Life, Study et Work)

- Fond : photo floutée (palmiers sur ordinateur, coucher de soleil sur mobile), voile sombre chaud par-dessus.
- Panneaux en « verre liquide » : fond blanc translucide léger, bordure blanche fine, `backdrop-filter: blur(16px)`.
- Texte blanc, police **Sora** (fine : 200-300 pour les titres). Éléments sélectionnés : fond blanc, texte `#1B1B1D`.
- Navigation : icônes des onglets en haut (icône + nom sur ordinateur, icônes seules sur mobile, juste après l'hibiscus).
- Life : l'hibiscus rond en haut à gauche ouvre la page Gestion (page d'accueil, accueil de Life, historique, réglages).
- Couleurs des émotions (Life) : Heureuse `#FD8A22`, Enjouée `#FF6E79`, Fatiguée `#73905C`, Anxieuse `#B83F6C`, Triste `#62A6E0`.
  L'aura de l'accueil mélange les 2 émotions les plus fréquentes des 7 derniers jours (une 3e en cas d'égalité).
- Style épuré : peu d'éléments, pas de cadres inutiles, pas de grosses pastilles.

## Points connus

- Le raccourci iPhone « Life » envoie pas, sommeil et règles (Clue via Apple Santé) à `vie_import`.
- Les réglages de la page de lancement sont propres à chaque appareil (localStorage `mog-launcher`).
- Idées en attente : widget iPhone avec Scriptable, migrer Work sur Supabase, importer les séances de sport depuis Forme.
