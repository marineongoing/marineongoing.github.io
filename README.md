# marineongoing

Mes apps perso pour organiser mes études et ma vie, construites avec Claude Code alors que je ne suis pas développeuse.

Site : https://marineongoing.github.io

## Les apps

- **Life** (`life/`) : accueil avec humeur du jour, santé (sommeil, pas, eau, sport, cycle), habitudes, finances (budget et reste à vivre), carrière, objectifs et journal. Claude met mes pages de journal au propre et me fait des recommandations.
- **Study** (`study/`) : mon BTS NDRC à l'INSEEC. Cours, devoirs, évaluations et révisions. Claude fait une synthèse de mes notes et me teste avec des quiz de 10 à 30 questions.

Chaque app s'installe sur l'écran d'accueil de l'iPhone comme une vraie app (PWA).

## Comment c'est fait

- Un fichier HTML par app, sans framework ni build, publié avec GitHub Pages.
- Base de données et connexion avec Supabase. Chaque utilisateur ne voit que ses propres données (règles RLS).
- Les appels à Claude passent par une petite fonction Supabase (`supabase/functions/claude`), pour que la clé API ne soit jamais dans le site.
- Un raccourci iPhone envoie mes données Apple Santé (pas, sommeil, cycle) dans Life.

## Travailler avec Claude Code

Le fichier [`CLAUDE.md`](CLAUDE.md) explique le projet à Claude : comment me parler, où se trouve chaque fichier, les règles à respecter (tester sur iPhone et ordinateur, ne jamais perdre de données, demander mon accord avant de publier) et la charte graphique. C'est ce qui me permet d'avancer avec Claude sans savoir coder.
