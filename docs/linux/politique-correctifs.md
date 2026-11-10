# Politique de correctifs Linux (B4)

S'applique à LNX-WEB01, LNX-OPS01, LNX-MON01 (Rocky Linux 10) et LNX-APP01 (Ubuntu Server LTS).
Les serveurs Windows suivent la politique WSUS de SRV-MGT01.

## 1. Correctifs automatiques (tous les jours)

| Système | Outil | Ce qui est installé | Déployé par |
|---|---|---|---|
| Rocky | `dnf-automatic.timer` | correctifs de **sécurité** seulement (`upgrade_type = security`) | rôle `auto_updates` |
| Ubuntu | `unattended-upgrades` | dépôt `-security` seulement (réglage par défaut d'Ubuntu) | rôle `auto_updates` |

Aucun redémarrage automatique : un noyau mis à jour attend la fenêtre de maintenance.
Les mises à jour qui ne sont pas de sécurité ne sont jamais automatiques : elles passent par la procédure manuelle ci-dessous.

## 2. Anneaux

| Anneau | Machines | Pourquoi |
|---|---|---|
| **Anneau 1** (test) | LNX-APP01, LNX-MON01 | Moins critiques : une panne ne coupe ni l'intranet ni l'administration |
| **Anneau 2** (production) | LNX-WEB01, puis LNX-OPS01 en dernier | Service rendu aux utilisateurs, et bastion qui pilote Ansible |

L'anneau 2 n'est traité qu'après **48 h** sans incident sur l'anneau 1.
Dans un anneau, les machines sont traitées une par une (`serial: 1`) : si l'une échoue, on s'arrête.

## 3. Fenêtres de maintenance

- Correctifs automatiques : chaque nuit (timer systemd, décalage aléatoire jusqu'à 1 h).
- Correctifs manuels et redémarrages : **mardi 20 h – 22 h** pour l'anneau 1, **jeudi 20 h – 22 h** pour l'anneau 2.
- Les sauvegardes tournent à 02:00 : aucune maintenance entre 01:30 et 03:00.

## 4. Urgences

Une faille critique (score CVSS ≥ 9, ou exploitée activement) n'attend pas la fenêtre :
1. décision du responsable Linux, notée dans le registre des changements ;
2. snapshot des VM concernées ;
3. passage de l'anneau 1, test rapide (30 min au lieu de 48 h), puis anneau 2 ;
4. rapport avant/après joint au registre.

## 5. Retour arrière

Avant chaque passage manuel : **snapshot VMware** de la machine (nom `avant-correctifs-AAAA-MM-JJ`).

| Problème | Action |
|---|---|
| Un paquet casse un service (Rocky) | `sudo dnf history list` puis `sudo dnf history undo <numéro>` |
| Un paquet casse un service (Ubuntu) | `sudo apt install <paquet>=<ancienne version>` (version lue dans `/var/log/apt/history.log`) |
| Nouveau noyau qui ne démarre pas | choisir l'ancien noyau dans le menu GRUB, puis `sudo grubby --set-default` sur l'ancien |
| Machine inutilisable | restaurer le snapshot, ou reconstruire (runbook « Reconstruire LNX-WEB01 ») |

## 6. Preuves

Chaque passage manuel produit un **rapport avant/après par machine** sur LNX-OPS01, dans
`~/rapports-correctifs/<date>/<machine>-avant.txt` et `-apres.txt` (playbook `ansible/correctifs.yml`).
Ces rapports montrent le noyau, les correctifs de sécurité en attente et l'historique des mises à jour.
Procédure : [runbook-correctifs.md](runbook-correctifs.md).
