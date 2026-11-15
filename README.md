# Projet Nexus360 – mission T01

Socle serveurs Linux et Windows du siège de Nexus360 : annuaire, intranet, partages de fichiers, exploitation (journaux, sauvegardes, supervision).
Projet de synthèse B3 Cybersécurité, Ynov Campus Nanterre, 2026-2027.

L'objectif fixé par la DSI : un serveur qui tombe se reconstruit depuis ce dépôt, une panne est vue avant que les utilisateurs appellent, et chaque changement est tracé et réversible.

> **État au 15/11/2026.** Le projet n'est pas terminé. Chaque rôle a construit sa partie, mais l'assemblage n'est pas fini : un seul contrôleur de domaine est en service (SRV-DC01), 2 machines sur 9 sont jointes au domaine de façon vérifiée, et le pipeline CI/CD ne s'exécute pas encore sur ce dépôt.
> Le détail, exigence par exigence, est dans le rapport de projet : [docs/rapport/](docs/rapport/).

## Sommaire

- [Équipe](#équipe)
- [Architecture](#architecture)
- [Contenu du dépôt](#contenu-du-dépôt)
- [Documentation](#documentation)
- [Déployer](#déployer)
- [Lancer la CI](#lancer-la-ci)
- [Preuves](#preuves)
- [Règles de travail](#règles-de-travail)
- [Problèmes connus](#problèmes-connus)

## Équipe

| Rôle | Membre | Machines | Dossiers |
|---|---|---|---|
| 1. Identité | Thomas (`@Thomrib1`) | SRV-DC01, SRV-DC02 | `identite/`, `windows/identite/` |
| 2. Services Windows | Aziz (`@abdulazizo2001`) | SRV-FS01, SRV-MGT01 | `windows/` |
| 3. Linux | Ugo (`@DropsUC`) | LNX-WEB01, LNX-OPS01, LNX-APP01 | `ansible/`, `docs/linux/` |
| 4. Exploitation | Dilane (`@idlane-max`) | LNX-MON01, runner CI sur LNX-OPS01, dépôt, pipeline | `monitoring/` |
| 5. Réseau et postes | Benor (`@benormh`) | LNX-GW01 à GW05, postes | `reseau/` |

## Architecture

Réseau du labo `10.36.0.0/16`, un `/24` par site (`10.36.1n.0/24` pour le site n), passerelle en `.1`. Chaque PC du groupe héberge un site sous VMware Workstation. Une passerelle Rocky Linux par site relie les sites par un tailnet Tailscale commun, **sans traduction d'adresses entre sites** : une machine garde son adresse d'un site à l'autre, ce qui permet à l'annuaire, à la supervision et aux sauvegardes de filtrer par adresse source.

| Machine | Rôle | Système | Adresse |
|---|---|---|---|
| SRV-DC01 | Contrôleur du domaine `ad.nexus360.test`, DNS, DHCP | Windows Server 2025 (bureau) | 10.36.11.10 |
| SRV-DC02 | Second contrôleur (**non promu** à ce jour) | Windows Server 2025 Core | 10.36.12.11 |
| SRV-FS01 | Serveur de fichiers : partages, quotas, filtrage | Windows Server 2025 Core | 10.36.11.12 |
| SRV-MGT01 | Administration, WSUS, collecte d'événements | Windows Server 2025 (bureau) | 10.36.12.13 |
| LNX-WEB01 | Intranet (nginx) | Rocky Linux 10 | 10.36.13.21 |
| LNX-OPS01 | Bastion SSH, Ansible, runner CI, sauvegardes | Rocky Linux 10 | 10.36.13.22 |
| LNX-MON01 | Journaux centralisés, Prometheus, Alertmanager, Grafana | Rocky Linux 10 | 10.36.12.23 (voir problème 5) |
| LNX-APP01 | Serveur applicatif hérité | Ubuntu Server LTS | 10.36.15.24 |
| CLI-W11-01 | Poste Comptabilité | Windows 11 Pro | 10.36.14.101 (réservation) |
| CLI-W11-02 | Poste Direction, anneau pilote | Windows 11 Pro | DHCP |
| CLI-LNX01 | Poste développeur | Ubuntu Desktop LTS | 10.36.14.102 (réservation) |
| LNX-GW0n | Passerelle du site n : routage, NAT vers Internet, MSS, tailnet, relais DHCP | Rocky Linux 10 | 10.36.1n.1 |

Annuaire : domaine `ad.nexus360.test` (NetBIOS `NEXUS360`), sites AD SITE1 à SITE5, racine d'OU `NEXUS360`, modèle AGDLP, administration en trois niveaux (T0, T1, T2), Windows LAPS, 9 GPO `N360-*`. DNS : 10.36.11.10 puis 10.36.12.11 ; redirecteurs 1.1.1.1 et 9.9.9.9.

LNX-MON01 a été déplacé par le rôle 4 du site 3 vers le site 2, pour que la supervision survive à une panne du site 3, qui porte le runner et les sauvegardes. Les autres adresses sont celles du sujet.

## Contenu du dépôt

```
.
├── README.md
├── Nexus360-soutenance.pptx   support de la soutenance intermédiaire du 10/11
├── ansible/                   Configuration des serveurs Linux (rôle 3)
│   ├── site.yml               point d'entrée
│   ├── correctifs.yml         correctifs par anneau, rapport avant/après
│   ├── inventory/             hosts.yml, group_vars/all.yml
│   └── roles/                 base, auto_updates, ssh_hardening, node_exporter, pare_feu_ubuntu,
│                              ops, backup_target, web, mon, gw
├── docs/
│   ├── linux/                 politique et runbook de correctifs (rôle 3)
│   └── rapport/               rapport de projet du groupe (PDF)
├── identite/                  Documentation de l'annuaire (rôle 1)
│   ├── bilan-blocages.md      état, blocages, tentatives sur DC02 : à lire en premier
│   ├── dat-identite.md, modele-administration.md, matrice-droits.md,
│   │   gpo-durcissement.md, runbook-creer-utilisateur.md, journal.md
│   ├── preuves/               21 captures de SRV-DC01 et leur index
│   └── exports/               emplacement des sorties texte
├── monitoring/                Exploitation (rôle 4)
│   ├── .github/               pipeline CI/CD, CODEOWNERS, modèles de PR et d'issue
│   ├── ansible/               site.yml, inventaire, rôle mon, fragments base et ops
│   ├── docs/exploitation/     guide du rôle, runbooks, DAT, modèle de PV, preuves, journal
│   ├── docs/organisation/     organisation de l'équipe, règles du dépôt
│   ├── hyperviseur/           démarrage ordonné des VM d'un site
│   ├── scripts/               bilan d'infrastructure, tests d'alertes, test de restauration
│   ├── tests/prometheus/      tests unitaires des règles d'alerte
│   ├── tools/                 génération du tableau de bord Grafana
│   ├── windows/               windows_exporter, déploiement Windows
│   └── CHANGELOG.md
├── reseau/                    Passerelles, tailnet, postes (rôle 5)
│   ├── gw-build.sh            construction d'une passerelle
│   ├── tests/gw-selftest.sh   14 contrôles d'une passerelle
│   ├── tailnet-policy.hujson  politique d'accès du tailnet, avec tests
│   ├── dhcp/                  configuration DHCP de secours (Kea)
│   ├── docs/                  DAT réseau, runbooks
│   ├── journal.md
│   └── preuves/               captures nommées par exigence
└── windows/                   Scripts PowerShell (rôles 1 et 2)
    ├── New-NexusShares.ps1, New-NexusFileScreens.ps1,
    │   Backup-NexusShares.ps1, Set-NexusServiceRecovery.ps1
    ├── config/                shares.json, filescreen.json, backup.json, services.json
    ├── docs/                  PV de restauration, preuves
    └── identite/              README des scripts de l'annuaire, script d'export des preuves (rôle 1)
```

## Documentation

| Sujet | Document |
|---|---|
| État du projet, bilan par exigence | [docs/rapport/](docs/rapport/) |
| Identité : bilan et blocages | [identite/bilan-blocages.md](identite/bilan-blocages.md) |
| Identité : DAT, administration, droits, GPO | [identite/README.md](identite/README.md) |
| Réseau : DAT, runbooks, journal | [reseau/README.md](reseau/README.md), [reseau/docs/dat-reseau.md](reseau/docs/dat-reseau.md) |
| Linux : politique de correctifs | [docs/linux/politique-correctifs.md](docs/linux/politique-correctifs.md) |
| Exploitation : guide du rôle 4 | [monitoring/docs/exploitation/GUIDE-ROLE4-EXPLOITATION.md](monitoring/docs/exploitation/GUIDE-ROLE4-EXPLOITATION.md) |
| Contrôle de cohérence du DAT | [monitoring/docs/exploitation/dat/controle-coherence-DAT.md](monitoring/docs/exploitation/dat/controle-coherence-DAT.md) |
| Organisation, hébergement des VM, dépendances | [monitoring/docs/organisation/ORGANISATION-EQUIPE.md](monitoring/docs/organisation/ORGANISATION-EQUIPE.md) |
| Règles du dépôt | [monitoring/docs/organisation/GITHUB-DEPOT.md](monitoring/docs/organisation/GITHUB-DEPOT.md) |
| Procès-verbal de restauration des partages | [windows/docs/pv-restauration.md](windows/docs/pv-restauration.md) |

Runbooks exigés (E2) :

| Procédure | Document |
|---|---|
| Créer un utilisateur | [identite/runbook-creer-utilisateur.md](identite/runbook-creer-utilisateur.md) |
| Restaurer un fichier | [monitoring/docs/exploitation/runbooks/restaurer-un-fichier.md](monitoring/docs/exploitation/runbooks/restaurer-un-fichier.md) |
| Redémarrer l'infrastructure dans l'ordre | [monitoring/docs/exploitation/runbooks/redemarrage-infrastructure.md](monitoring/docs/exploitation/runbooks/redemarrage-infrastructure.md) |
| Appliquer les correctifs | [docs/linux/runbook-correctifs.md](docs/linux/runbook-correctifs.md) |
| Reconstruire une passerelle | [reseau/docs/runbooks.md](reseau/docs/runbooks.md) |
| Reconstruire LNX-WEB01 depuis zéro | à écrire |

Journaux d'exploitation (D4) : [reseau/journal.md](reseau/journal.md), [identite/journal.md](identite/journal.md), [monitoring/docs/exploitation/journal-exploitation.md](monitoring/docs/exploitation/journal-exploitation.md). Registre des changements : [monitoring/CHANGELOG.md](monitoring/CHANGELOG.md).

## Déployer

Règle commune : simuler d'abord (`--check` pour Ansible, `-WhatIf` pour PowerShell), appliquer ensuite, puis relancer. Le second passage ne doit rien changer.

### Ordre de démarrage

1. Passerelles LNX-GW0n, sur chaque PC.
2. Contrôleurs de domaine.
3. LNX-MON01.
4. Serveurs membres : SRV-FS01, SRV-MGT01, LNX-OPS01, LNX-WEB01, LNX-APP01.
5. Postes.

Puis `bash monitoring/scripts/check-infra.sh` depuis le bastion. Démarrage outillé par PC : `monitoring/hyperviseur/Start-NexusSite.ps1 -Site <n>`.

### Passerelle d'un site (rôle 5)

```bash
sudo /root/gw-build.sh <n>          # n = numéro du site, 1 à 5
sudo /root/gw-selftest.sh <n>       # attendu : 14 PASS, 0 FAIL
```

Variables dans `/root/gw.env`, jamais versionné (modèles : `reseau/gw.env.example`, `reseau/gw.env.tailnet.example`). Détail : [reseau/README.md](reseau/README.md).

### Annuaire (rôle 1)

Sur SRV-DC01, avec un compte T0. L'ordre des scripts et leur état sont dans [windows/identite/README.md](windows/identite/README.md). Les scripts de configuration eux-mêmes ne sont pas encore versionnés (problème 7).

Vérifications rapides, en PowerShell sur SRV-DC01 :

```powershell
Get-ADDomainController -Filter * | select HostName, Site, IPv4Address
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=NEXUS360,DC=ad,DC=nexus360,DC=test" | measure
Get-GPO -All | ? DisplayName -like 'N360-*' | select DisplayName
Get-DhcpServerv4Scope
```

### Serveurs Linux (rôle 3)

Depuis LNX-OPS01, avec le compte et la clé `ansible` :

```bash
cd ansible
ansible-playbook site.yml --check --diff     # simulation
ansible-playbook site.yml                    # application
ansible-playbook site.yml                    # second passage : changed=0 attendu
```

Tant qu'une machine n'est pas jointe au domaine : `ansible-playbook site.yml --skip-tags base`.
Correctifs par anneau : `ansible-playbook correctifs.yml -l lnx-app01,lnx-mon01` (voir le runbook).

### Supervision (rôle 4)

```bash
cd monitoring/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --check --diff
ansible-playbook site.yml
```

Le rôle `mon` exige un coffre Ansible : modèle dans `monitoring/ansible/inventory/group_vars/all/vault.yml.example`, mot de passe fourni par la variable `ANSIBLE_VAULT_PASSWORD`. Seul le fichier chiffré est versionné.

Contrôle sur LNX-MON01 :

```bash
systemctl is-active rsyslog prometheus alertmanager blackbox_exporter grafana-server
curl -s localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.instance) \(.health)"'
```

Grafana n'est pas exposé : `ssh -L 3000:<adresse de LNX-MON01>:3000 <compte>@10.36.13.22`, puis `http://localhost:3000`.

Agents Windows : `monitoring/windows/scripts/Install-WindowsExporter.ps1` (avec un compte T0 sur les DC, T1 ailleurs).

Sauvegardes, chaque nuit : `/etc` de chaque Linux vers LNX-OPS01 à 01:30, ACL de SRV-FS01 à 01:45, partages vers LNX-OPS01 à 02:00 ; rétention 7 jours.

### Serveurs Windows (rôle 2)

Sur le serveur concerné, console PowerShell en administrateur, à la racine du dépôt :

```powershell
.\windows\New-NexusShares.ps1 -WhatIf          # SRV-FS01 : dossiers, partages, droits NTFS, quotas
.\windows\New-NexusShares.ps1
.\windows\New-NexusFileScreens.ps1             # SRV-FS01 : filtrage des exécutables
.\windows\Set-NexusServiceRecovery.ps1         # SRV-FS01 et SRV-MGT01 : redémarrage automatique des services
.\windows\Backup-NexusShares.ps1               # SRV-FS01 : sauvegarde des partages, rétention 7 jours
```

## Lancer la CI

Le pipeline est décrit dans `monitoring/.github/workflows/pipeline.yml`.

| Événement | Ce que fait le pipeline |
|---|---|
| Pull request vers `main` | Analyse statique (gitleaks, yamllint, ansible-lint, promtool, shellcheck, PSScriptAnalyzer) sur un runner GitHub, puis simulation sur l'infrastructure (`ansible-playbook --check --diff`, PowerShell `-WhatIf`) |
| Fusion dans `main` | Analyse, déploiement Linux, second passage qui doit afficher `changed=0`, déploiement Windows depuis SRV-MGT01, tests de fumée |
| Manuel | Onglet **Actions**, workflow **pipeline**, bouton **Run workflow** : sert aussi à reconstruire un serveur |

Prérequis :
- le runner auto-hébergé `lnx-ops01` sur LNX-OPS01 (étiquettes `self-hosted`, `linux`, `nexus360`), sous le compte dédié `ghrunner`, sans port entrant ;
- le secret `ANSIBLE_VAULT_PASSWORD` dans **Settings > Secrets and variables > Actions** ; `GRAFANA_TOKEN` est facultatif ;
- un dépôt **privé** : un runner auto-hébergé sur un dépôt public exécuterait le code de n'importe qui.

Contrôle local avant un push, depuis `monitoring/` :

```bash
yamllint . && ansible-lint --profile production ansible/
promtool check rules ansible/roles/mon/files/rules/*.yml
promtool test rules tests/prometheus/alertes_test.yml
shellcheck scripts/*.sh
```

> **Le pipeline ne se déclenche pas sur ce dépôt.** GitHub ne lit que les workflows placés dans `.github/workflows/` à la racine. Pour l'activer, il faut déplacer `monitoring/.github/` à la racine et aligner les chemins du workflow : il attend `ansible/requirements.yml`, `ansible/roles/mon/`, `scripts/` et `tests/prometheus/` à la racine, alors qu'ils sont sous `monitoring/`. Le déploiement attend aussi, côté annuaire, les comptes `svc-backup` et `svc-deploy` et l'enregistrement DNS `lnx-mon01`.

## Preuves

| Rôle | Emplacement | Contenu |
|---|---|---|
| 1. Identité | [identite/preuves/](identite/preuves/README.md) | 21 captures de SRV-DC01 : forêt, sites, DNS, DHCP, OU, utilisateurs, groupes AGDLP, comptes par niveau, PSO, GPO, récupération des services |
| 2. Services Windows | [windows/docs/preuves/](windows/docs/preuves/) | Idempotence (A7), récupération des services (C1), sauvegarde et restauration (C3) |
| 4. Exploitation | [monitoring/docs/exploitation/preuves/](monitoring/docs/exploitation/preuves/README.md) | Tableau des preuves d'alertes, à remplir |
| 5. Réseau et postes | [reseau/preuves/](reseau/preuves/) | Captures nommées par exigence : A2, A8, B5, C4, E1, E3 |

Aucune capture ne doit montrer de mot de passe, de clé ou de jeton.

## Règles de travail

- Une branche courte par tâche, une pull request, une relecture par un autre membre avant fusion.
- Chacun committe avec son propre compte : c'est ce qui mesure la contribution individuelle.
- Messages de commit explicites, avec l'exigence concernée : `feat(identite): … (B1)`.
- **Aucun secret dans le dépôt** : ni mot de passe, ni clé privée, ni jeton, ni capture qui en montre un. Un secret poussé une fois reste dans l'historique : il doit être changé.
- Retour arrière : `git revert <commit>`, puis pull request.
- Livraison : étiquette `v1.0` sur le commit livré, avant le gel.

## Problèmes connus

| # | Problème | Conséquence |
|---|---|---|
| 1 | SRV-DC02 n'est pas promu (six essais, voir [identite/bilan-blocages.md](identite/bilan-blocages.md)) | Pas de réplication, pas de basculement DHCP, un seul point de panne pour l'annuaire |
| 2 | 2 machines sur 9 jointes au domaine de façon vérifiée (LNX-OPS01, LNX-WEB01) ; LNX-MON01 déclarée jointe, à vérifier | Droits des partages, `sudo` par groupe AD, LAPS, WSUS et collecte d'événements non testables |
| 3 | Pipeline placé sous `monitoring/.github/` | Aucune exécution de CI sur ce dépôt |
| 4 | Deux arborescences Ansible : `ansible/` (rôle 3) et `monitoring/ansible/` (rôle 4), avec deux rôles `mon` et deux inventaires | À fusionner en un seul point d'entrée |
| 5 | Adresse de LNX-MON01 fixée à 10.36.12.23 par le rôle 4, mais le dépôt porte encore 10.36.13.23 (`ansible/inventory`, `reseau/tailnet-policy.hujson`) et 10.36.14.23 (`monitoring/ansible/inventory`, `scripts/nexus.env`, `windows/config/supervision.json`). SRV-FS01 (10.36.11.12 ou 10.36.12.12) et site des postes (4 ou 5) non tranchés | Cibles de supervision et filtrage par source incohérents |
| 6 | Noms de groupes AD différents entre les rôles 1, 2 et 3 | Droits NTFS et `sudo` non appliqués : voir [identite/matrice-droits.md](identite/matrice-droits.md) §6 |
| 7 | Scripts PowerShell de configuration de l'annuaire non versionnés | L'annuaire ne peut pas encore être reconstruit depuis le dépôt |
| 8 | Branches non fusionnées : `windows/investigation` (boîte à outils D2), `windows/wsus-config` (WSUS, B4), `windows/tout`, `reseau/tailscale-gw04` | Absents de `main` |
| 9 | Sauvegardes centralisées sur un seul site (LNX-OPS01) | Règle 3-2-1 non respectée : copie hors site proposée |
| 10 | Visibilité du dépôt à vérifier | Doit être privé, un runner auto-hébergé y est attaché |
| 11 | Pas d'étiquette `v1.0` | À poser sur le commit livré |
