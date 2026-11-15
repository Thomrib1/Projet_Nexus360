# DAT – Identité (rôle 1) – Nexus360 T01

Auteur : Thomas · Périmètre : SRV-DC01, SRV-DC02, annuaire `ad.nexus360.test`, DNS, DHCP, GPO, comptes à privilèges.
État au 15/11/2026. Exigences couvertes : A1, A2 (part annuaire), B1, B3, B5 (part GPO), C1 et C4 (part DC).

> **Comment lire ce document.** Les valeurs viennent des fichiers de configuration appliqués sur SRV-DC01
> (`windows/identite/config/*.json|csv`). La colonne « État » dit ce qui est réellement en place.
> Les preuves (sorties de commandes et captures) sont dans `docs/identite/exports/` et `docs/identite/preuves/`.
> Une ligne sans preuve versée reste « déclarée » : voir [preuves/README.md](preuves/README.md).

## 1. Vue d'ensemble

```
        SITE1 – 10.36.11.0/24 (PC de Thomas)            SITE2 – 10.36.12.0/24 (PC de Dilane)
   ┌────────────────────────────────────┐          ┌────────────────────────────────────┐
   │ SRV-DC01  10.36.11.10              │          │ SRV-DC02  10.36.12.11              │
   │ Windows Server 2025 (bureau)       │          │ Windows Server 2025 Core           │
   │ AD DS, DNS, DHCP, PDC, 5 rôles FSMO│          │ rôles installés, NON PROMU         │
   │ passerelle 10.36.11.1 (LNX-GW01)   │          │ passerelle 10.36.12.1 (LNX-GW02)   │
   └──────────────┬─────────────────────┘          └──────────────┬─────────────────────┘
                  │        tailnet Tailscale (routeurs de sous-réseau, sans NAT)         │
                  └───────────────────── LNX-GW01 ◄──────────► LNX-GW02 ─────────────────┘
```

| Élément | Valeur | État |
|---|---|---|
| Forêt / domaine | `ad.nexus360.test`, NetBIOS `NEXUS360`, DN `DC=ad,DC=nexus360,DC=test` | Fait |
| SRV-DC01 | 10.36.11.10/24, passerelle 10.36.11.1, SITE1, Windows Server 2025 avec bureau | Fait |
| SRV-DC02 | 10.36.12.11/24, passerelle 10.36.12.1, SITE2, Windows Server 2025 Core | Préparé, **non promu** |
| Rôles FSMO | Les 5 sur SRV-DC01 | Fait (un seul DC) |
| Réplication | DC01 ↔ DC02 | **Non fait** (dépend de DC02) |

## 2. Choix techniques

### 2.1 Forêt et domaine

- Un seul domaine, une seule forêt : 480 collaborateurs, un seul périmètre d'administration. Plusieurs domaines n'apporteraient que de la complexité.
- Suffixe `.test` : réservé par la RFC 6761, il ne peut pas entrer en conflit avec un nom public.
- Le sous-domaine `ad.` sépare l'annuaire d'un éventuel nom public `nexus360.*`.
- Les DC restent dans `OU=Domain Controllers`. Les déplacer casserait la *Default Domain Controllers Policy*.

### 2.2 Sites et sous-réseaux AD

| Site | Sous-réseau | Contenu |
|---|---|---|
| SITE1 | 10.36.11.0/24 | SRV-DC01 |
| SITE2 | 10.36.12.0/24 | SRV-DC02 |
| SITE3 | 10.36.13.0/24 | serveurs Linux |
| SITE4 | 10.36.14.0/24 | postes |
| SITE5 | 10.36.15.0/24 | postes, LNX-APP01 |

Pourquoi 5 sites : chaque PC du groupe est un site derrière un tunnel. Sans sites déclarés, un client peut s'authentifier sur le DC le plus éloigné. Les passerelles ne traduisent pas les adresses entre sites (`--snat-subnet-routes=false`) : l'annuaire voit la vraie adresse source et l'associe au bon site.

État : fait (5 sites, 5 sous-réseaux, liens de sites).

### 2.3 DNS

| Paramètre | Valeur | Justification |
|---|---|---|
| Zone directe | `ad.nexus360.test`, intégrée à AD | Répliquée avec l'annuaire, mises à jour sécurisées |
| Zones inverses | une par /24 du labo | PTR exigés par A1 |
| Redirecteurs | 1.1.1.1 et 9.9.9.9 | Deux fournisseurs distincts ; la sortie passe par le NAT de la passerelle |
| Enregistrements | A et PTR de tous les serveurs du plan, alias `intranet` → `lnx-web01` | A1, A3 |
| Vieillissement | 7 jours + 7 jours, nettoyage sur DC01 seul | Purge les baux disparus sans toucher aux enregistrements statiques |
| Interfaces d'écoute | 10.36.11.10 et 127.0.0.1 | Voir l'incident « adresses 100.x » ci-dessous |
| DNS client de DC01 | 127.0.0.1 tant que DC02 n'existe pas ; ensuite 10.36.12.11 puis 127.0.0.1 | Le partenaire d'abord évite l'« îlot DNS » au démarrage |

**Risque traité : adresses Tailscale dans le DNS.** SRV-DC01 a enregistré son adresse Tailscale (100.x) et celle de sa carte NAT dans la zone. Un client pouvait alors recevoir une adresse injoignable pour `SRV-DC01`. Correction : enregistrement DNS désactivé sur ces cartes, enregistrements A parasites supprimés, écoute limitée à 10.36.11.10. Contrôle : `Resolve-DnsName srv-dc01.ad.nexus360.test` ne doit renvoyer que 10.36.11.10 (preuve à verser).

### 2.4 Heure

- L'émulateur PDC (SRV-DC01) suit `0.fr.pool.ntp.org`, `1.fr.pool.ntp.org` et `2.fr.pool.ntp.org`. Il est déclaré source fiable du domaine.
- SRV-DC02 et les membres Windows suivent la hiérarchie du domaine (réglage par défaut).
- Les Linux utilisent chrony vers 10.36.11.10 et 10.36.12.11 (rôle Linux, exigence A2).
- La synchronisation d'heure de l'hyperviseur est désactivée sur les DC : elle écraserait NTP. Kerberos tolère 5 minutes d'écart.
- Dépendance : sortie UDP 123 par LNX-GW01.

### 2.5 DHCP

| Paramètre | Valeur | État |
|---|---|---|
| Serveur | SRV-DC01, autorisé dans AD | Fait |
| Étendue `POSTES-SITE4` | 10.36.14.100 à .200, bail 1 jour, routeur 10.36.14.1 | Fait |
| Étendue `POSTES-SITE5` | 10.36.15.100 à .200, bail 1 jour, routeur 10.36.15.1 | Fait |
| Options | DNS 10.36.11.10 puis 10.36.12.11, suffixe `ad.nexus360.test`, posées **sur l'étendue** | Fait |
| Réservations | CLI-W11-01 → 10.36.14.101, CLI-LNX01 → 10.36.14.102 (par adresse MAC) | Fait |
| Mises à jour DNS | Toujours, suppression à l'expiration, protection de nom, compte `svc-dhcp-dns` | Fait |
| Basculement `FO-DC01-DC02` | Équilibrage de charge 50/50, MCLT 1 h, bascule automatique après 30 min | **Non fait** (dépend de DC02) |
| Relais | LNX-GW04 et LNX-GW05 vers 10.36.11.10 et 10.36.12.11 (rôle Réseau) | Voir `reseau/` |

Choix à retenir :

- **Options sur l'étendue, pas sur le serveur.** Le basculement réplique les étendues et leurs options, pas les options de niveau serveur.
- **Équilibrage 50/50 plutôt que secours passif.** Les deux DC sont des pairs sur deux PC, tous deux à un saut de tailnet des relais. Aucun n'est « local ».
- **Compte dédié `svc-dhcp-dns`.** Les enregistrements des clients n'appartiennent pas au compte ordinateur du DC. Sinon un DC pourrait écraser n'importe quel enregistrement.
- **Plage .100 à .200.** Elle laisse les adresses fixes hors plage (LNX-APP01 en 10.36.15.24).

Écart connu avec le rôle Réseau : le DHCP de substitution du labo (`reseau/dhcp/kea-substitut.json`) distribue .110 à .200. Les réservations et les options sont identiques.

### 2.6 Unités d'organisation

```
OU=NEXUS360
├── Admin         (gérée uniquement par T0)
│   ├── T0 / Comptes, Groupes, Services
│   ├── T1 / Comptes, Groupes, Services
│   └── T2 / Comptes, Groupes
├── Serveurs      (T1) / Windows, Linux          ← GPO serveurs, LAPS serveurs
├── Postes        (T2) / Windows, Pilote, Linux  ← GPO postes, LAPS postes, anneau pilote WSUS
├── Utilisateurs  / Nouveaux, Direction, Compta, IT, RH, Commercial, Dev
├── Groupes       / Globaux (GG_*), DomaineLocal (DL_*)
├── Desactives
└── Quarantaine   ← ordinateurs joints sans OU cible : aucune GPO métier
```

Justification (B1) :

- **Premier niveau par niveau d'administration.** Les GPO de tiering et les délégations s'appliquent à une OU entière, sans exception à gérer.
- **Second niveau par type d'objet.** Une GPO « postes » ne touche jamais un serveur.
- **`Pilote`** isole CLI-W11-02 pour le ciblage WSUS (anneau pilote du rôle Services Windows).
- **`Quarantaine` et `Nouveaux`** remplacent les conteneurs par défaut `Computers` et `Users`. Une machine jointe sans OU cible n'y reçoit aucune GPO métier.

État : fait (33 OU, racine comprise). Détail des comptes et des niveaux : [modele-administration.md](modele-administration.md). Groupes : [matrice-droits.md](matrice-droits.md).

### 2.7 Mots de passe

| Population | Porteur | Longueur | Historique | Durée max. | Verrouillage |
|---|---|---|---|---|---|
| Utilisateurs | GPO `N360-Domaine-Comptes` | 12 | 24 | 365 j | 10 essais / 15 min |
| Comptes à privilèges (`t0-`, `t1-`, `t2-`) | PSO `PSO-Comptes-Privilegies` (préséance 10) | 16 | 24 | 180 j | 5 essais / 30 min |
| Comptes de service (`svc-`) | PSO `PSO-Comptes-Service` (préséance 20) | 24, généré | 24 | 365 j | aucun |

Pas de verrouillage sur les comptes de service : un attaquant pourrait sinon bloquer un service en se trompant volontairement de mot de passe. La longueur de 24 caractères générés compense.

### 2.8 GPO

Neuf GPO `N360-*`. Détail et justification : [gpo-durcissement.md](gpo-durcissement.md).

### 2.9 Récupération des services (C1)

Les services critiques de SRV-DC01 redémarrent seuls après un plantage : 3 redémarrages (30 s, 60 s, 120 s), compteur remis à zéro après 24 h. Liste des services : `windows/identite/config/services-recovery.json`.
Contrôle : `sc.exe qfailure DNS`. Test : `Stop-Process -Name dns -Force`, puis `Get-Service DNS` 30 secondes plus tard.

## 3. Comptes de service

| Compte | OU | Usage | Niveau | Mot de passe |
|---|---|---|---|---|
| `svc-adjoin` | Admin/T1/Services | Jonction des machines (membre de `DL_T1_Jonction` et `DL_T2_Jonction`) | T1 | 24 car., généré, hors dépôt |
| `svc-dhcp-dns` | Admin/T0/Services | Mises à jour DNS faites par le DHCP | T0 | 24 car., généré, hors dépôt |

Comptes attendus par d'autres rôles et **pas encore créés** : `svc-backup` et `svc-deploy` (rôle Exploitation, voir `monitoring/docs/organisation/ORGANISATION-EQUIPE.md`).

## 4. Flux et ports

| Flux | Source → destination | Ports |
|---|---|---|
| Authentification, annuaire | toutes les machines → DC | TCP/UDP 53, 88, 389, 464 ; TCP 445, 636, 3268 |
| Réplication, promotion | DC ↔ DC | TCP 135, 49152-65535 (RPC dynamiques), 389, 445, 88 ; TCP 9389 (ADWS) |
| Administration à distance | SRV-DC01 → SRV-DC02 | TCP 5985 (WinRM) |
| Heure | membres → DC ; DC01 → Internet | UDP 123 |
| DHCP | relais LNX-GW04/05 → DC | UDP 67 |
| Supervision | LNX-MON01 → DC | TCP 9182 (windows_exporter, à installer sur les DC) |

Ces ports sont ouverts entre sites par la règle 2 de `reseau/tailnet-policy.hujson`.

## 5. Ce qui se passe quand un PC est éteint

| PC éteint | Conséquence aujourd'hui | Conséquence visée (après promotion de DC02) |
|---|---|---|
| PC de Thomas (DC01) | **Plus d'authentification, de DNS ni de DHCP** : DC01 est le seul DC | DC02 assure les trois services |
| PC de Dilane (DC02) | Aucune (DC02 n'est pas promu) | DC01 assure les trois services |

C4 (arrêt d'un DC sans coupure) n'est donc pas tenu aujourd'hui.

## 6. Dérogations et risques connus

| Réf. | Dérogation / risque | Mesure |
|---|---|---|
| R-ID-01 | Un seul DC en service : point unique de panne | Promotion de DC02 en priorité ; pas d'instantané restauré sur DC01 |
| R-ID-02 | Basculement DHCP absent | Étendues prêtes sur DC01 ; basculement à créer dès que DC02 existe |
| R-ID-03 | Comptes d'administration nominatifs **fictifs** (`lmartin`, `ebernard`, `hdubois`) | À remplacer par les membres du groupe si l'intervenant le demande |
| R-ID-04 | Le compte `Administrateur` intégré a servi pendant la mise en place | À consigner au journal ; ne plus l'utiliser, le garder sous enveloppe |
| R-ID-05 | Mots de passe initiaux générés dans un fichier CSV hors dépôt, visible sur une capture le 10/11 | Fichier à supprimer ; comptes T0 et `svc-adjoin` à réinitialiser ; capture à ne jamais verser |
| R-ID-06 | LAPS et GPO serveurs/postes non testés : aucun serveur ou poste Windows n'est joint | Test dès la jonction de SRV-FS01, SRV-MGT01 et des postes |
| R-ID-07 | Noms de groupes différents chez les rôles Linux et Services Windows | Voir [bilan-blocages.md](bilan-blocages.md) §4 |
| R-ID-08 | Dépôt hébergé sur le compte personnel du rôle 1 | Voir R-EXP-08 du rôle Exploitation |
| R-ID-09 | Jamais d'instantané VMware restauré sur un DC | Risque de retour en arrière des numéros de séquence (USN) et de réplication corrompue |

## 7. Vérification

Le script `Test-N360Identity.ps1` a donné **47 OK, 12 ECHEC, 8 ALERTE** le 10/11/2026, avant toute promotion de DC02. Presque tous les ECHEC viennent de l'absence de DC02. Un ECHEC venait d'un défaut du test (joker `?` dans un filtre AD), corrigé.
Contrôle rapide de DC01 : `dcdiag /skip:systemlog /skip:dfsrevent /q`.
