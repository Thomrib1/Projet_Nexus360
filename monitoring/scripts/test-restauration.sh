#!/usr/bin/env bash
# =============================================================================
# test-restauration.sh — Test de restauration consigné (exigence C3), à lancer sur LNX-OPS01.
# Restaure dans un répertoire temporaire (jamais en place) puis compare avec l'original.
# Produit un bloc Markdown à coller dans le procès-verbal (docs/exploitation/pv/).
#
# Propriétaire : rôle 4 — Exécuté sur : LNX-OPS01 (VM du PC du rôle 3), en root
# Dépend de    : rôle 3 (/srv/backup), rôle 2 (partages + fichier de test choisi avec le service),
#                rôle 4 (sauvegardes planifiées et déjà exécutées au moins une fois)
#
#   sudo bash scripts/test-restauration.sh etc lnx-web01 etc/nginx/nginx.conf
#   sudo bash scripts/test-restauration.sh partage Compta "<chemin/relatif/fichier.xlsx>"
# =============================================================================
set -euo pipefail
type="${1:?etc|partage}"; source="${2:?machine ou partage}"; chemin="${3:?fichier à restaurer}"
work="$(mktemp -d /tmp/nexus-restore.XXXX)"
debut=$(date +%s)

case "$type" in
  etc)
    archive="$(find /srv/backup/etc/"$source" -name "*.tar.gz" -printf "%T@ %p\n" | sort -n | tail -1 | cut -d" " -f2-)"
    echo ">> Archive utilisée : $archive"
    tar --acls --xattrs --selinux -xzf "$archive" -C "$work" "$chemin"
    restaure="$work/$chemin"
    sum_orig="$(ssh -o BatchMode=yes "$source" sudo sha256sum "/$chemin" | cut -d' ' -f1)"
    ;;
  partage)
    snap="$(readlink -f /srv/backup/fs01/latest)"
    archive="$snap/$source/$chemin"
    echo ">> Instantané utilisé : $snap"
    cp -a "$archive" "$work/"
    restaure="$work/$(basename "$chemin")"
    mnt=/mnt/nexus-fs01/verif; mkdir -p "$mnt"
    mount -t cifs "//srv-fs01.ad.nexus360.test/$source" "$mnt" -o ro,credentials=/etc/nexus-backup/fs01.cred,vers=3.1.1,seal
    sum_orig="$(sha256sum "$mnt/$chemin" | cut -d' ' -f1)"; umount "$mnt"
    ;;
  *) echo "type inconnu" >&2; exit 2 ;;
esac

sum_rest="$(sha256sum "$restaure" | cut -d' ' -f1)"
duree=$(( $(date +%s) - debut ))
verdict=$([[ "$sum_orig" == "$sum_rest" ]] && echo "CONFORME" || echo "NON CONFORME (fichier modifié depuis la sauvegarde ?)")

cat <<EOF

| Élément | Valeur |
|---|---|
| Date du test | $(date '+%F %T') |
| Opérateur | ${SUDO_USER:-$USER} |
| Type / source | $type / $source |
| Fichier restauré | \`$chemin\` |
| Sauvegarde utilisée | \`$archive\` |
| Restauré dans | \`$restaure\` |
| SHA-256 original | \`$sum_orig\` |
| SHA-256 restauré | \`$sum_rest\` |
| Durée de restauration | ${duree} s |
| Résultat | **$verdict** |
EOF
