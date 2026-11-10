# Runbook : appliquer les correctifs Linux (E2)

**Où :** sur LNX-OPS01, compte `ugo`, dossier `~/Projet_Nexus360/ansible`.
**Durée :** environ 15 min par anneau.
**Règles :** voir [politique-correctifs.md](politique-correctifs.md) (anneaux, fenêtres, urgences).

## 1. Préparer

1. Faire un snapshot VMware de chaque machine de l'anneau (nom `avant-correctifs-AAAA-MM-JJ`).
2. Vérifier que toutes les machines répondent :
   `ansible linux -m ping`
3. Noter le changement dans le registre des changements.

## 2. Appliquer l'anneau 1 (LNX-APP01, LNX-MON01)

```
ansible-playbook correctifs.yml -l lnx-app01,lnx-mon01
```

Si un redémarrage est nécessaire (nouveau noyau), relancer avec :

```
ansible-playbook correctifs.yml -l lnx-app01,lnx-mon01 -e correctifs_reboot=true
```

## 3. Vérifier

1. `PLAY RECAP` : `failed=0` sur chaque machine.
2. Les services tournent : `ansible app,mon -b -m command -a 'systemctl --failed --no-pager'` doit afficher `0 loaded units listed`.
3. Les rapports existent : `ls ~/rapports-correctifs/$(date +%F)/`. Il doit y avoir un fichier `-avant.txt` et un `-apres.txt` par machine.
4. Dans `-apres.txt`, la section « Correctifs de sécurité en attente » est vide.

## 4. Anneau 2 (48 h plus tard)

```
ansible-playbook correctifs.yml -l lnx-web01,lnx-ops01
```

LNX-OPS01 n'est jamais redémarré par le playbook (c'est lui qui pilote Ansible).
S'il a besoin d'un redémarrage : `sudo systemctl reboot` à la main, puis vérifier le runner et le timer de sauvegarde (runbook « Après un redémarrage »).

Vérifier ensuite l'intranet : `curl -s http://10.36.13.21 | grep Version`.

## 5. En cas de problème

Voir la section « Retour arrière » de la politique : `dnf history undo`, ancien noyau dans GRUB, ou restauration du snapshot.

## 6. Clore

1. Joindre les rapports avant/après au registre des changements.
2. Supprimer les snapshots une semaine plus tard si tout va bien.
