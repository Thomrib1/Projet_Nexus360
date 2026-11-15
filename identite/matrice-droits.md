# Matrice des droits (B1)

État au 15/11/2026. Les groupes existent sur SRV-DC01. Les droits NTFS et Linux sont posés par les rôles Services Windows et Linux : voir les écarts au §6.

## 1. Convention AGDLP

**A**ccounts → **G**lobal → **D**omain **L**ocal → **P**ermissions.

| Préfixe | Étendue | Contient | Porte une permission ? | Exemple |
|---|---|---|---|---|
| `GG_` | Globale | Des comptes : un **rôle** métier ou d'administration | Non | `GG_Compta` |
| `DL_` | Domaine local | Des groupes globaux : un **droit sur une ressource** | Oui, eux seuls | `DL_FS_Compta_RW` |

Forme des `DL_` : `DL_<Système>_<Ressource>_<Droit>`. Système : `FS` (serveur de fichiers), `LNX` (Linux), `T1` ou `T2` (administration). Droit : `RW` (modification), `RO` (lecture), ou un verbe.

Règles :

- Un compte n'est jamais placé directement dans un `DL_`.
- Une ACL ne cite jamais un compte ni un `GG_`.
- Un `DL_` n'est jamais membre d'un `GG_`.

Conséquence : une arrivée = ajouter la personne à son `GG_` de service. Un nouveau droit = ajouter un `GG_` dans un `DL_`. Les ACL des serveurs ne bougent pas.

## 2. Groupes métier (OU `Groupes/Globaux`)

| Groupe | Rôle | Membres connus |
|---|---|---|
| `GG_Direction` | Direction | pgarnier, slaurent, olemaire, cmoreau |
| `GG_Compta` | Comptabilité | jpetit, croux, nfournier |
| `GG_IT` | DSI (comptes standards) | à relever dans l'export |
| `GG_RH` | Ressources humaines | à relever dans l'export |
| `GG_Commercial` | Commercial | à relever dans l'export |
| `GG_Dev` | Développement | mfaure, schevalier |
| `GG_Personnel` | Tout le personnel | les six groupes ci-dessus |

Les 17 utilisateurs sont importés depuis `windows/identite/config/users.csv` : pgarnier, slaurent, olemaire, jpetit, croux, nfournier, cmoreau, lmartin, ebernard, hdubois, imercier, agirard, mlefebvre, cbonnet, ilambert, mfaure, schevalier. Le mot de passe initial doit être changé à la première connexion.
Répartition complète par service : `docs/identite/exports/B1-utilisateurs.txt`.

## 3. Partages de SRV-FS01

| Partage | Groupe de ressource (ACL NTFS) | Droit NTFS | Membres |
|---|---|---|---|
| **Compta** | `DL_FS_Compta_RW` | Modification | `GG_Compta` |
| | `DL_FS_Compta_RO` | Lecture et exécution | `GG_Direction` |
| **Direction** | `DL_FS_Direction_RW` | Modification | `GG_Direction` |
| | `DL_FS_Direction_RO` | Lecture et exécution | vide (réservé) |
| **Commun** | `DL_FS_Commun_RW` | Modification | `GG_Personnel` |
| | `DL_FS_Commun_RO` | Lecture et exécution | vide (prestataires, auditeurs) |
| tous | Administrateurs locaux de SRV-FS01 | Contrôle total | `DL_T1_Srv_AdminLocal` ← `GG_T1_Admins` |

Vue « qui accède à quoi » :

| Groupe | Compta | Direction | Commun |
|---|:---:|:---:|:---:|
| `GG_Compta` | **RW** | – | **RW** |
| `GG_Direction` | RO | **RW** | **RW** |
| `GG_IT`, `GG_RH`, `GG_Commercial`, `GG_Dev` | – | – | **RW** |
| `t1-*` (administration locale) | admin | admin | admin |

Avec l'énumération basée sur l'accès, un comptable ne voit pas le dossier `Direction`.

## 4. Linux (B2)

| Groupe de ressource | Effet sur les Linux | Membres | Comptes |
|---|---|---|---|
| `DL_LNX_SSH_Acces` | Ouverture de session SSH | `GG_LNX_Admins`, `GG_LNX_Exploitation` | t1-lmartin, t1-ebernard, t1-hdubois |
| `DL_LNX_Sudo_Admins` | `sudo` complet | `GG_LNX_Admins` | t1-lmartin, t1-ebernard |
| `DL_LNX_Sudo_Exploitation` | `sudo` restreint à une liste de commandes, sans shell | `GG_LNX_Exploitation` | t1-hdubois |
| `DL_LNX_Poste_Acces` | Ouverture de session sur CLI-LNX01 | `GG_Dev` | mfaure, schevalier |

## 5. Administration

| Groupe de ressource | Droit | Membres |
|---|---|---|
| Admins du domaine | Contrôle total de l'annuaire (T0) | `GG_T0_Admins` ← t0-lmartin, t0-ebernard |
| `DL_T1_Srv_AdminLocal` | Administrateur local des serveurs Windows membres | `GG_T1_Admins` |
| `DL_T1_LAPS_Lecture` | Lecture LAPS de OU=Serveurs | `GG_T1_Admins` |
| `DL_T1_AD_GestionComptes` | Gestion des utilisateurs et des groupes métier | `GG_T1_Admins` |
| `DL_T1_Jonction` | Jonction dans OU=Serveurs | `GG_T1_Admins`, `svc-adjoin` |
| `DL_T2_Postes_AdminLocal` | Administrateur local des postes Windows | `GG_T2_Admins` ← t2-hdubois, t2-ebernard |
| `DL_T2_LAPS_Lecture` | Lecture LAPS de OU=Postes | `GG_T2_Admins` |
| `DL_T2_Support_ResetMdp` | Réinitialisation de mot de passe, déverrouillage | `GG_T2_Admins` |
| `DL_T2_Jonction` | Jonction dans OU=Postes | `GG_T2_Admins`, `svc-adjoin` |

## 6. Écarts à corriger avec les autres rôles

Les fichiers des autres rôles citent des groupes qui n'existent pas dans l'annuaire. Tant que ce n'est pas aligné, les droits ne s'appliquent pas.

| Fichier | Ce qu'il contient | Ce qui existe dans l'annuaire | Effet |
|---|---|---|---|
| `windows/config/shares.json` | `DL_Compta_RW`, `DL_Compta_R`, `DL_Direction_RW`, `DL_Direction_R`, `DL_Commun_RW`, `DL_Commun_R` | `DL_FS_<Partage>_RW` et `DL_FS_<Partage>_RO` | `New-NexusShares.ps1` affiche « Groupes introuvables : droits NTFS ignorés » |
| `windows/config/shares.json` | `"NetBIOSDomain": "AD"` | `NEXUS360` | Même effet : aucun groupe n'est résolu |
| `ansible/inventory/group_vars/all.yml` | `ssh_allowed_groups: [GG_Admins_T1, GG_Exploitation]` | `DL_LNX_SSH_Acces` | SSSD (`simple_allow_groups`) et `AllowGroups` refusent tous les comptes du domaine |
| `ansible/inventory/group_vars/all.yml` | `sudo_full_groups: [GG_Admins_T1]`, `sudo_restricted_group: GG_Exploitation` | `DL_LNX_Sudo_Admins`, `DL_LNX_Sudo_Exploitation` | Aucune règle `sudo` ne s'applique |

Deux façons d'aligner : les rôles 2 et 3 reprennent les noms ci-dessus (une ligne chacun), ou le rôle 1 crée les groupes qu'ils attendent. La première respecte AGDLP : les droits sont portés par des `DL_`.

## 7. Tests d'accès à faire (A5, B2)

| Session | Depuis | Attendu |
|---|---|---|
| `croux` (Compta) | CLI-W11-01 | écrit dans Compta et Commun ; ne voit pas Direction |
| `pgarnier` (Direction) | CLI-W11-01 | lit Compta sans pouvoir écrire ; écrit dans Direction |
| `mfaure` (Dev) | CLI-LNX01 | ne voit que Commun |
| `t1-hdubois` | SSH sur LNX-WEB01 par le bastion | `sudo systemctl restart nginx` autorisé ; `sudo -i` refusé |

État : **bloqués**. Ni SRV-FS01 ni les postes ne sont joints au domaine.
