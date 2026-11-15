# Identité (rôle 1) : scripts et données

Contrôleurs de domaine SRV-DC01 et SRV-DC02, annuaire `ad.nexus360.test`, DNS, DHCP, GPO, comptes à privilèges.
Documentation : [`docs/identite/`](../../docs/identite/README.md).

## Contenu

| Élément | Rôle | État dans le dépôt |
|---|---|---|
| `scripts/Export-N360Preuves.ps1` | Exporte l'état réel de l'annuaire en fichiers texte (lecture seule) | Présent — **jamais exécuté à ce jour** : relire la sortie au premier passage |
| `scripts/01` à `18`, `Test-N360Identity.ps1`, `modules/` | Configuration de l'annuaire, idempotente, avec `-WhatIf` (A7) | **À verser** depuis `C:\N360\depot` sur SRV-DC01 |
| `config/*.json`, `config/*.csv` | Données qui pilotent les scripts (OU, groupes, utilisateurs, DHCP, GPO…) | **À verser** |

Les scripts de configuration ont été exécutés sur SRV-DC01 mais ne sont pas encore dans Git. C'est la version de `C:\N360\depot` qui fait foi : elle contient les corrections faites pendant l'exécution (ordre des paramètres DNS du DHCP, filtre des comptes par niveau, remise à zéro de `$LASTEXITCODE`).

## Verser les scripts dans le dépôt

Sur le PC de Thomas, dans sa copie du dépôt :

```powershell
git switch -c identite/scripts-config
# copier depuis SRV-DC01 (C:\N360\depot\windows) :
#   scripts\*  ->  windows\identite\scripts\
#   config\*   ->  windows\identite\config\
git status
```

**Avant le commit, vérifier que `git status` ne montre aucun de ces fichiers :**

- `secrets-*.csv` ou tout fichier du dossier `N360-secrets` (mots de passe initiaux) ;
- `*.log` (journaux de `C:\N360\logs`) ;
- une sauvegarde de GPO contenant des préférences avec mot de passe.

Le `.gitignore` de la racine bloque ces motifs. Un secret poussé une fois reste dans l'historique : il doit alors être changé.

Faire **plusieurs commits**, un par lot cohérent, avec le compte de Thomas. Exemples de messages :

```
feat(identite): forêt, sites et DNS de SRV-DC01 (A1)
feat(identite): OU, groupes AGDLP et import de 17 utilisateurs depuis CSV (B1)
feat(identite): comptes T0/T1/T2, PSO, délégations et LAPS (B3)
feat(identite): GPO de durcissement et de tiering (B3, B5)
feat(identite): DHCP sur SRV-DC01, basculement prêt pour SRV-DC02 (A1)
docs(identite): DAT, modèle d'administration, matrice des droits, runbook, bilan (E1, E2)
docs(identite): preuves et exports de SRV-DC01
```

Puis `git push -u origin identite/scripts-config`, pull request, relecture par un autre membre.

## Ordre d'exécution des scripts

Toujours un passage `-WhatIf` avant le passage réel. Un second passage réel doit afficher 0 changement.

| # | Objet | Exigence | Machine | État |
|---|---|---|---|---|
| 01 | Premier DC : forêt et domaine | A1 | SRV-DC01 | Exécuté |
| 03 | Sites et sous-réseaux AD | A1 | SRV-DC01 | Exécuté |
| 04 | DNS | A1 | SRV-DC01 | Exécuté (à relancer après DC02) |
| 05 | Unités d'organisation | B1 | SRV-DC01 | OU créées à la console |
| 06 | Groupes AGDLP | B1 | SRV-DC01 | Exécuté |
| 07 | Comptes d'administration et de service | B3 | SRV-DC01 | Exécuté |
| 08 | Stratégies de mot de passe affinées | B3 | SRV-DC01 | Exécuté |
| 12 | Import des utilisateurs depuis `users.csv` | B1 | SRV-DC01 | Exécuté (17 comptes) |
| 13 | Délégations | B3 | SRV-DC01 | Exécuté |
| 14 | LAPS | B3 | SRV-DC01 | Exécuté |
| 15 | GPO | B3, B5 | SRV-DC01 | Exécuté |
| 18 | Export des GPO (sauvegardes et rapports HTML) | B5 | SRV-DC01 | À faire, puis verser les rapports |
| 10 | Heure | A1 | SRV-DC01 | Exécuté (à relancer après DC02) |
| 11 | Récupération des services | C1 | SRV-DC01 | Exécuté (à relancer sur DC02) |
| 09 | DHCP et basculement | A1 | SRV-DC01 puis SRV-DC02 | Étendues faites ; basculement en attente |
| 02 | Second DC | A1 | SRV-DC02 | **Échec** : voir `docs/identite/bilan-blocages.md` §5 |
| 16, 17 | Comptes ordinateur et jonction | A2 | chaque machine | 2 machines Linux jointes |
| – | `Test-N360Identity.ps1` : contrôle d'ensemble | toutes | SRV-DC01 | 47 OK, 12 ECHEC, 8 ALERTE le 10/11 |

États repris du bilan du 10/11. Les numéros et les noms exacts des fichiers sont ceux du dossier réel : corriger ce tableau s'ils diffèrent.

## Exporter les preuves

Sur SRV-DC01, console PowerShell en administrateur, compte T0 :

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Export-N360Preuves.ps1
```

Le script écrit une vingtaine de fichiers `.txt` et les rapports HTML des GPO dans `C:\N360\exports-preuves\<date>\`.
Relire les fichiers, puis les copier dans `docs/identite/exports/`. La liste des preuves attendues est dans [`docs/identite/preuves/README.md`](../../docs/identite/preuves/README.md).

## Règles

- Aucun mot de passe dans un fichier, un journal ou une capture.
- Jamais de restauration d'instantané VMware sur un contrôleur de domaine.
- Le compte `Administrateur` intégré ne sert plus : utiliser un compte `t0-*`. Toute exception va au journal.
