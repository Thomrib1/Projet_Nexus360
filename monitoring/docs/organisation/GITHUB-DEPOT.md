# Le dépôt GitHub : qui le crée, comment il est configuré, comment chacun travaille

## 1. Qui fait quoi

Le dépôt a été **créé par le rôle 1**, sur son compte personnel GitHub **Pro**. Les autres membres et l'intervenant y sont **collaborateurs**.
Sur un dépôt personnel, **seul le propriétaire a accès à l'onglet *Settings*** : les collaborateurs peuvent créer des branches, pousser du code, ouvrir et fusionner des PR, gérer les issues, les étiquettes et les jalons, mais pas configurer le dépôt.

| Qui | Action | Quand |
|---|---|---|
| **Rôle 1 (propriétaire)** | Protection de `main`, réglages des PR, secrets, jeton d'enregistrement du runner, clés de déploiement, invitations — **guidé par le rôle 4** (§3) | Séance 1–2 |
| **Rôle 4 (responsable du dépôt et du pipeline)** | Structure du dépôt, `CODEOWNERS`, modèles de PR et d'issue, workflow du pipeline, étiquettes, jalons, tableau de suivi ; installation du runner ; étiquette `v1.0` | Séance 1 → gel |
| Chaque membre | Accepte l'invitation, configure git sur son PC, travaille par branches + PR | Séance 1 |
| Tout le monde | Relit les PR dont il est propriétaire du code (titulaire ou binôme) | En continu |

## 2. Pourquoi le compte du rôle 1

GitHub ne permet de **protéger une branche d'un dépôt privé** (PR obligatoire, relecture obligatoire, interdiction de pousser directement sur `main`) qu'avec **GitHub Pro, Team ou Enterprise**. Une organisation gratuite ne le permet que sur un dépôt public. Le rôle 1 est le membre qui a GitHub Pro (via le *GitHub Student Developer Pack*) : le dépôt est donc sur son compte.

Conséquences à connaître :
- **Le pipeline reste la responsabilité du rôle 4** : c'est lui qui dit au rôle 1 quoi configurer, et c'est lui qui écrit tout ce qui est dans le dépôt.
- Les collaborateurs ont **tous** l'écriture (pas de lecture seule possible sur un dépôt personnel), intervenant compris.
- **Impossible de restreindre qui pousse sur quelle branche** (cette fonction n'existe que pour les organisations). Seule `main` est protégée, et c'est elle qui compte : c'est la seule qui est déployée. La convention `r<N>/…` et l'auteur de chaque commit indiquent à qui appartient une branche. Limite à inscrire au DAT.
- Sur un dépôt privé, la validation manuelle d'un déploiement par « environnement GitHub » n'existe sur aucune formule : le contrôle humain, c'est **la PR relue et approuvée**.

## 3. Configuration (faite par le rôle 1, guidé par le rôle 4)

### Méthode rapide (script)

Le script détecte que le dépôt existe déjà : il saute la création et applique seulement la configuration.

```bash
# sur le PC du rôle 1 (git + GitHub CLI installés), dans sa copie du dépôt
gh auth login                                     # avec le compte du RÔLE 1 (propriétaire)
export MEMBRES="pseudo-role2 pseudo-role3 pseudo-role4 pseudo-role5"
export INTERVENANT="pseudo-intervenant"
bash scripts/github/init-depot.sh nexus360
```

Le script active la suppression automatique des branches fusionnées, invite tout le monde, crée les étiquettes par rôle et les jalons J1–J4, protège `main`, puis demande le secret `ANSIBLE_VAULT_PASSWORD`.

### Ce qui est configuré (à vérifier dans *Settings*, ou à faire à la main)

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Visibilité | **Private** | Exigence du sujet ; obligatoire avec un runner auto-hébergé |
| Collaborators | 4 membres + intervenant | Intervenant invité dès la séance 1 (exigence du sujet) |
| Branches → `main` | PR obligatoire, **1 approbation**, **relecture d'un propriétaire du code**, approbations annulées si nouveau commit, contrôle « Analyse statique » obligatoire et à jour, conversations résolues, **pas de push forcé ni de suppression**, **règles appliquées aux administrateurs** | « On travaille par branches et pull requests, relues par un autre membre avant fusion » |
| General → Pull Requests | merge commit + squash autorisés, rebase interdit, *Automatically delete head branches* | Historique lisible, branches propres |
| Secrets → Actions | `ANSIBLE_VAULT_PASSWORD`, `GRAFANA_TOKEN` | Aucun secret dans le dépôt |
| Actions → Runners | le rôle 1 génère le jeton (*New self-hosted runner*, valable 1 h) et le transmet aussitôt au rôle 4, qui enregistre `lnx-ops01`, label `nexus360` (guide §5) | Déploiement sur l'infrastructure |
| Deploy keys | clé **lecture seule** de SRV-MGT01 (générée par le rôle 2, ajoutée par le rôle 1) | MGT01 récupère le code sans compte personnel |
| Projects | Tableau *À faire / En cours / En revue / Fait* | Suivi des jalons, visible par l'intervenant |

Au jalon J3, ajouter « Vérification à blanc (check / WhatIf) » aux contrôles obligatoires (il nécessite le runner).

## 4. Les branches : une par tâche, pas une par personne

**Question fréquente : « chaque rôle doit-il avoir sa branche ? »** → **Non, pas de branche permanente par personne.** Chaque personne crée **une branche courte par tâche**, préfixée par son rôle, fusionnée par PR puis supprimée.

| Branche | Durée de vie | Qui y pousse | Rôle |
|---|---|---|---|
| `main` | permanente, protégée | personne directement (uniquement par PR) | état de référence, **seul ce qui est sur main est déployé** |
| `r<N>/<type>-<sujet>` | quelques heures à 2 jours | son auteur | une tâche = une branche = une PR |

Exemples : `r1/feat-import-utilisateurs-csv`, `r2/feat-quotas-fsrm`, `r3/fix-sssd-sudo`, `r4/feat-alertes-sauvegarde`, `r5/feat-tailnet-policy`, `r4/docs-pv-restauration`.

Pourquoi pas une branche permanente `role4` ?
- elle s'éloigne de `main` pendant des semaines → conflits énormes à la fusion, intégration tardive (un jalon raté) ;
- le pipeline ne déploie que `main` : une branche personnelle n'est jamais testée sur l'infrastructure réelle ;
- les petites PR sont relues vraiment ; une PR de 3 semaines de travail ne l'est pas.

La contribution individuelle reste parfaitement visible : chaque commit porte le compte de son auteur (*Insights → Contributors*), et chaque PR porte l'étiquette de son rôle.

## 5. Ce que fait chaque membre sur son PC (une fois)

```bash
git config --global user.name  "Prénom Nom"
git config --global user.email "adresse-liée-au-compte-github@exemple.fr"
ssh-keygen -t ed25519 -C "prenom@nexus360"          # puis ajouter la clé publique dans GitHub > Settings > SSH keys
git clone git@github.com:<compte-role1>/<nom-du-depot>.git
```

## 6. Le cycle de travail (tous les rôles)

```bash
git switch main && git pull                              # partir de la dernière version
git switch -c r4/feat-alerte-raid                        # une branche pour la tâche
# ... travail ...
git add -p                                               # relire ce qu'on ajoute
git commit -m "feat(mon): alerte RaidDegrade sur le miroir de LNX-OPS01"
git push -u origin r4/feat-alerte-raid
gh pr create --fill --label role-4-exploitation          # ou bouton "Compare & pull request"
# → GitHub demande automatiquement la relecture aux propriétaires du code (CODEOWNERS)
# → le pipeline analyse et fait le --check / -WhatIf ; le relecteur lit le diff et le résultat
# → après approbation : "Merge pull request" → déploiement automatique → branche supprimée
```

**Messages de commit** : `type(périmètre): description à l'impératif`
types : `feat` (nouvelle fonction), `fix`, `docs`, `ci`, `refactor`, `test`, `chore` · périmètres : `base`, `web`, `ops`, `mon`, `ad`, `fs`, `wsus`, `gw`, `tailnet`, `pipeline`, `dat`…

**Relecture** : le relecteur vérifie que le diff fait ce que dit la PR, que le `--check`/`-WhatIf` ne montre rien d'inattendu, qu'il n'y a pas de secret, que le journal d'exploitation est à jour, et qu'il saurait expliquer ce changement en soutenance.

## 7. Qui possède quels dossiers (`.github/CODEOWNERS`)

| Dossier | Titulaire | Binôme (relecteur) |
|---|---|---|
| `windows/identite/`, `windows/config/utilisateurs*.csv` | Rôle 1 | Rôle 2 |
| `windows/` (le reste) | Rôle 2 | Rôle 1 |
| `ansible/roles/base`, `web`, `ops` | Rôle 3 | Rôle 4 |
| `.github/`, `ansible/roles/mon`, `ansible/inventory`, `scripts/`, `tests/`, `docs/` | **Rôle 4** | Rôle 3 |
| fragments exploitation dans `base` et `ops` | **Rôle 4** | Rôle 3 |
| `hyperviseur/` | **Rôle 4** | Rôle 5 |
| `reseau/` | Rôle 5 | Rôle 4 |
| `docs/incidents/`, journal d'exploitation | tout le monde | n'importe quel autre membre |

Deux propriétaires par dossier : GitHub interdit d'approuver sa propre PR, il faut donc toujours un second propriétaire pour fusionner.

## 8. Livraison

```bash
git switch main && git pull
git tag -a v1.0 -m "Livraison mission T01 — Nexus360"
git push origin v1.0
```
Fait par le rôle 4 (les étiquettes ne demandent que l'écriture), **avant la veille de la séance 6 à 23 h 59**. Ce qui est poussé après n'est pas évalué.

## 9. Si un secret est poussé par erreur

1. Le considérer comme **compromis** (le sujet est explicite) : le **changer** immédiatement (mot de passe AD, clé, jeton).
2. Retirer le fichier par une PR, et noter l'incident au journal d'exploitation.
3. Le pipeline (gitleaks) analyse tout l'historique : il restera rouge. Une fois le secret **changé**, le rôle 4 ajoute l'empreinte affichée par gitleaks (`Fingerprint: <commit>:<fichier>:<règle>:<ligne>`) dans un fichier `.gitleaksignore` à la racine, par une PR qui explique que le secret a été révoqué.
