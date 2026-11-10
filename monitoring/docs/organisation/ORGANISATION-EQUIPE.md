# Organisation de l'équipe : rôles, PC, machines virtuelles, dépendances

Équipe de **5 personnes = 5 rôles = 5 PC = 5 sites**. Hyperviseur : **VMware Workstation** sur chaque PC.
Les 5 sites sont reliés par un **tailnet Tailscale** propre au groupe : la passerelle Rocky de chaque PC est routeur de sous-réseau.
**Règle de placement : chaque personne héberge sur son PC les VM de son rôle**, à une exception près, imposée par le sujet : les deux DC doivent être sur deux PC différents.

## 1. Qui héberge quoi

| PC / site | Personne (rôle) | Réseau du site | VM hébergées | Adresses | RAM conseillée des VM |
|---|---|---|---|---|---|
| **PC 1** · site 1 | Rôle 1 — Identité | 10.36.11.0/24 | LNX-GW01, SRV-DC01 | .1, .10 | 1 + 4 Go → **PC ≥ 8 Go** |
| **PC 2** · site 2 | Rôle 2 — Services Windows | 10.36.12.0/24 | LNX-GW02, **SRV-DC02 (administré par le rôle 1)**, SRV-FS01, SRV-MGT01 | .1, .11, .12, .13 | 1 + 2 + 2 + 4 Go → **PC ≥ 16 Go** |
| **PC 3** · site 3 | Rôle 3 — Linux | 10.36.13.0/24 | LNX-GW03, LNX-WEB01, LNX-OPS01, LNX-APP01 (Ubuntu) | .1, .21, .22, .24 | 1 + 1,5 + 2 + 1,5 Go → **PC ≥ 12 Go** |
| **PC 4** · site 4 | **Rôle 4 — Exploitation** | 10.36.14.0/24 | LNX-GW04, **LNX-MON01** | .1, .23 | 1 + 4 Go → **PC ≥ 8 Go** |
| **PC 5** · site 5 | Rôle 5 — Réseau et postes | 10.36.15.0/24 | LNX-GW05, CLI-W11-01, CLI-LNX01, CLI-W11-02 | .1, .101, .102, .103 (DHCP réservé) | 1 + 4 + 3 + 4 Go → **PC ≥ 16 Go** |

- Les **3 derniers octets sont ceux du sujet**. Seul le 3e octet change (site = numéro du rôle), comme le sujet l'autorise (« seul le troisième octet change, et le plan d'adressage du DAT fait foi »).
- SRV-DC02 est sur le PC 2 : il est **installé et démarré** par la personne du rôle 2, mais **configuré et administré** par le rôle 1, à distance (RSAT depuis SRV-MGT01, ou console VMware partagée pendant les séances). Cette même répartition DC02 + MGT01 figure dans la répartition de référence du sujet.
- **Si un PC manque de RAM** : le PC 4 (rôle 4) est le moins chargé et peut accueillir CLI-LNX01. Il prend alors l'adresse 10.36.14.102, et le rôle 5 ajoute un relais DHCP sur LNX-GW04. Mettre à jour le DAT, `hosts.ini` et `scripts/nexus.env`.
- Le sujet demande que le DAT documente **la RAM réelle de chaque PC** : chacun la relève sur son PC (`Gestionnaire des tâches > Performances`).

### Ce qui se passe quand un PC est éteint (à mettre dans le DAT)

| PC éteint | Perdu | Continue de fonctionner |
|---|---|---|
| PC 1 (DC01) | DC01 ; accès du site 1 | Authentification, DNS, DHCP par **DC02** (PC 2) |
| PC 2 (DC02, FS01, MGT01) | Partages, WSUS, collecte WEF, console d'admin, déploiement Windows du pipeline | Authentification, DNS, DHCP par **DC01** |
| PC 3 (WEB01, OPS01, APP01) | Intranet, **pipeline (runner)**, bastion, sauvegardes | AD, partages, **supervision (qui alerte)** |
| PC 4 (MON01) | **Supervision, alertes, centralisation des journaux** (les journaux sont gardés en file d'attente sur chaque Linux et arrivent au retour de MON01) | Tous les services utilisateurs |
| PC 5 (postes) | Postes de travail | Tous les serveurs |

## 2. Qui installe et qui configure chaque VM

| VM | Installée sur son PC par | Configurée par | Comment |
|---|---|---|---|
| LNX-GW0n (une par PC) | la personne du PC n | **Rôle 5** | script de reconstruction de passerelle (`reseau/`) lancé par chacun, ou par le rôle 5 via le tailnet |
| SRV-DC01 | Rôle 1 | Rôle 1 | console, puis scripts `windows/identite/` |
| SRV-DC02 | Rôle 2 (hébergement) | **Rôle 1** | promotion DC + DNS + basculement DHCP |
| SRV-FS01, SRV-MGT01 | Rôle 2 | Rôle 2 | scripts PowerShell depuis MGT01 |
| LNX-WEB01, LNX-OPS01, LNX-APP01 | Rôle 3 | Rôle 3 (`base`, `web`, `ops`), avec les **fragments du rôle 4** (supervision, journaux, sauvegardes) | Ansible via le pipeline |
| **LNX-MON01** | **Rôle 4** | **Rôle 4** (rôle `mon`) + rôle 3 (rôle `base`) | Ansible via le pipeline |
| CLI-W11-01, CLI-W11-02, CLI-LNX01 | Rôle 5 | Rôle 5 (+ GPO du rôle 1, `base` du rôle 3 pour CLI-LNX01) | jonction au domaine, tests d'accès |

## 3. Réseau VMware sur chaque PC (consignes du rôle 5, appliquées par chacun sur son PC)

```
 PC n (Windows + VMware Workstation + client Tailscale du membre)
 ┌───────────────────────────────────────────────────────────────────────────┐
 │  LNX-GW0n  carte 1 : NAT (VMnet8)  ──► Internet + Tailscale (tailscaled)   │
 │            carte 2 : LAN Segment "Nexus-Site-n" ── 10.36.1n.1/24           │
 │                                     │                                      │
 │  VM du site : une seule carte sur le LAN Segment "Nexus-Site-n"            │
 │  IP fixe 10.36.1n.x/24, passerelle 10.36.1n.1, DNS 10.36.11.10 + 10.36.12.11│
 └───────────────────────────────────────────────────────────────────────────┘
```

- **LAN Segment** (VM > Settings > Network Adapter > LAN segment) plutôt qu'un réseau *host-only* : c'est un commutateur isolé, sans DHCP VMware ni adresse de l'hôte qui pourrait entrer en conflit avec la passerelle en `.1`.
- Sur la passerelle (rôle 5) : `tailscale up --advertise-routes=10.36.1n.0/24 --snat-subnet-routes=false --accept-routes`, routage IPv4 activé, NAT vers Internet uniquement pour la sortie, ajustement du MSS, routes approuvées dans la console Tailscale.
- **`--snat-subnet-routes=false` est indispensable pour le rôle 4** : sans lui, les paquets venant d'un autre site arriveraient avec l'adresse de la passerelle et non leur vraie adresse source. Les règles « port 9100 ouvert uniquement à 10.36.14.23 » et la commande SSH forcée `from=` des sauvegardes ne fonctionneraient plus.
- Dans chaque VM Rocky : `dnf install open-vm-tools` (fait par le rôle `base`). C'est ce qui permet l'arrêt propre par `vmrun stop soft`.

## 4. Matrice des dépendances entre rôles

Lecture : la ligne **a besoin** de la colonne.

| ↓ a besoin de → | Rôle 1 | Rôle 2 | Rôle 3 | Rôle 4 | Rôle 5 |
|---|---|---|---|---|---|
| **Rôle 1** | — | héberger DC02 sur le PC 2 | — | dépôt Git, pipeline | passerelles + tailnet (réplication DC01↔DC02 entre PC 1 et 2) |
| **Rôle 2** | domaine, comptes, groupes AGDLP, GPO | — | — | pipeline (déploiement Windows), MSI windows_exporter | tailnet, postes pour tester les partages |
| **Rôle 3** | DNS, SSSD (domaine), groupes AD pour sudo/SSH | — | — | fragments supervision/journaux/sauvegardes, pipeline | tailnet, NAT pour `dnf` |
| **Rôle 4** | DNS (`lnx-mon01`, `intranet`), comptes `svc-backup` et `svc-deploy`, son compte d'exploitation | OpenSSH + clone sur MGT01, droits `svc-backup`, `icacls`, aide windows_exporter | **VM LNX-OPS01 (runner)**, `base` appliqué, RAID/LVM `/srv/backup`, intégration des fragments | — | **passerelle LNX-GW04**, tailnet sans SNAT, politique autorisant les flux de supervision/journaux/sauvegarde |
| **Rôle 5** | DHCP en basculement (étendue, options), GPO postes | — | `base` pour CLI-LNX01 | pipeline, supervision des passerelles | — |

### Chemin critique (ce qui bloque tout le monde)

1. **Rôle 5** : les 5 passerelles dans le tailnet → sans elles, aucun PC ne voit les autres.
2. **Rôle 1** : DC01, puis DC02 qui réplique → sans annuaire, aucune jonction, aucun SSSD.
3. **Rôle 4** : le dépôt Git (séance 1). Le pipeline arrive ensuite (J3) et dépend de LNX-OPS01, fourni par le rôle 3.
4. **Rôle 3** : LNX-OPS01 joint au domaine → le rôle 4 peut y installer le runner.

Pendant que les rôles 1 et 5 sont bloquants (séances 1–2), le rôle 4 avance sans dépendance : dépôt, structure, analyse statique du pipeline, installation de LNX-MON01, DAT v1.

## 5. Interfaces à négocier tôt (réunion de 10 min en séance 1)

| Sujet | Entre | À fixer |
|---|---|---|
| Plan d'adressage, noms | tous, arbitré par le **rôle 4** (cohérence DAT) | ce document + `hosts.ini` + `scripts/nexus.env` |
| DHCP | 1 (basculement) ↔ 5 (relais) | étendue des postes 10.36.15.0/24, options, réservations |
| Sauvegardes (C3) | 3 (`/srv/backup`, `/etc`) ↔ 2 (FS01) ↔ **4 (planification, test, PV)** | heures (01:30 `/etc`, 01:45 `icacls`, 02:00 partages), compte `svc-backup` |
| Supervision (C2) | 3 (node_exporter via `base`) ↔ 2 (windows_exporter) ↔ **4 (rôle `mon`, alertes)** | ports 9100/9182, service Windows critique choisi pour l'alerte |
| Pipeline | 2 et 3 fournissent scripts/rôles ↔ **4 propriétaire** | runner sur OPS01, compte `svc-deploy`, `deploiement.json` |
| Politique du tailnet | **5 propriétaire** ↔ 4 (flux d'exploitation) | voir la matrice des flux du guide du rôle 4 |
