#!/usr/bin/env bash
# =============================================================================
# test-alertes.sh — Déclenche VOLONTAIREMENT chaque alerte et archive la preuve (exigence C2).
#
# Propriétaire : rôle 4 (Exploitation)
# Exécuté sur  : LNX-OPS01 (bastion, VM du PC du rôle 3), par le rôle 4
# Dépend de    : rôle 4 (rôle Ansible mon déployé sur LNX-MON01), rôle 3 (sudo du groupe d'exploitation
#                sur les Linux, RAID d'OPS01), rôle 2 (windows_exporter installé avec lui ; test Windows
#                lancé depuis SRV-MGT01 avec un compte T1), rôle 5 (tailnet : OPS01 et MON01 joignent tous les sites)
# Prévenir le propriétaire de la machine avant chaque test (journal d'exploitation).
#
# Chaque test :
#   1. provoque la panne ; 2. attend que l'alerte passe en "firing" dans Alertmanager ;
#   3. enregistre la preuve JSON dans docs/exploitation/preuves/ ; 4. répare.
#
#   bash scripts/test-alertes.sh liste
#   bash scripts/test-alertes.sh instance-down      lnx-web01
#   bash scripts/test-alertes.sh disque             lnx-web01
#   bash scripts/test-alertes.sh cpu                lnx-web01
#   bash scripts/test-alertes.sh service-linux      lnx-web01
#   bash scripts/test-alertes.sh intranet
#   bash scripts/test-alertes.sh sauvegarde
#   bash scripts/test-alertes.sh windows-service    (instructions : se fait depuis SRV-MGT01)
# =============================================================================
set -euo pipefail
# shellcheck source=scripts/nexus.env
source "$(dirname "$0")/nexus.env"
AM="http://$MON:9093/api/v2/alerts"
PREUVES="$(cd "$(dirname "$0")/.." && pwd)/docs/exploitation/preuves"
mkdir -p "$PREUVES"

attendre_alerte() {  # $1 = nom d'alerte ; $2 = délai max (s)
  local nom="$1" max="${2:-420}" t=0
  echo ">> Attente de l'alerte $nom (max ${max}s)…"
  while (( t < max )); do
    if curl -fsS "$AM?active=true&filter=alertname%3D%22$nom%22" | jq -e 'length > 0' >/dev/null; then
      local f
      f="$PREUVES/$(date +%F_%H%M%S)_${nom}.json"
      curl -fsS "$AM?filter=alertname%3D%22$nom%22" | jq '.' > "$f"
      echo ">> ALERTE REÇUE après ${t}s — preuve : $f"
      echo ">> Pensez à la capture d'écran Grafana/Discord pour le dossier."
      return 0
    fi
    sleep 15; t=$((t + 15))
  done
  echo "!! Alerte $nom non reçue après ${max}s" >&2; return 1
}

hote="${2:-lnx-web01}"
case "${1:-liste}" in
  liste)
    grep '^#   bash scripts/test-alertes.sh' "$0" | cut -c2- ;;

  instance-down)   # node_exporter arrêté => cible injoignable
    ssh "$hote" sudo systemctl stop node_exporter
    attendre_alerte InstanceDown 240 || true
    ssh "$hote" sudo systemctl start node_exporter ;;

  disque)          # remplit /var/tmp jusqu'à 90 %
    ssh "$hote" 'set -e; avail=$(df --output=avail -B1 /var/tmp | tail -1); size=$(df --output=size -B1 /var/tmp | tail -1);
                 need=$(( avail - size / 10 )); sudo fallocate -l "$need" /var/tmp/nexus-test-disque.bin'
    attendre_alerte EspaceDisqueFaible 300 || true
    ssh "$hote" sudo rm -f /var/tmp/nexus-test-disque.bin ;;

  cpu)             # sature tous les cœurs pendant 7 min
    ssh "$hote" 'for i in $(seq "$(nproc)"); do timeout 420 sh -c "while :; do :; done" & done; disown -a' &
    attendre_alerte CPUSature 480 || true
    ssh "$hote" 'pkill -f "while :; do :; done" || true' ;;

  service-linux)   # une unité "nexus-test-echec" qui échoue => état failed
    ssh "$hote" sudo systemd-run --unit=nexus-test-echec.service /bin/false || true
    attendre_alerte ServiceLinuxEnEchec 180 || true
    ssh "$hote" sudo systemctl reset-failed nexus-test-echec.service ;;

  intranet)        # arrêt PROPRE de nginx : Restart=on-failure ne le relance pas (normal)
    ssh lnx-web01 sudo systemctl stop nginx
    attendre_alerte IntranetIndisponible 180 || true
    ssh lnx-web01 sudo systemctl start nginx ;;

  sauvegarde)      # on vieillit artificiellement la métrique de LNX-WEB01
    f=/var/lib/node_exporter/textfile/nexus_backup_age.prom
    sudo cp "$f" /tmp/nexus_backup_age.prom.bak
    sudo sed -i -E 's/(source="lnx-web01"\} )[0-9]+/\11000000000/' "$f"
    sudo systemctl stop nexus-backup-maintenance.timer
    attendre_alerte SauvegardeTropAncienne 480 || true
    sudo systemctl start nexus-backup-maintenance.service nexus-backup-maintenance.timer ;;

  windows-service)
    cat <<'EOF'
Depuis SRV-MGT01 (PowerShell, compte T1) — DHCP de SRV-DC02 : le partenaire de basculement DC01 continue à servir
  Invoke-Command -ComputerName SRV-DC02 { Stop-Service DHCPServer }
Puis ici :  bash scripts/test-alertes.sh attendre WindowsServiceCritiqueArrete
Réparation : Invoke-Command -ComputerName SRV-DC02 { Start-Service DHCPServer }
EOF
    ;;

  attendre)
    attendre_alerte "${2:?indiquer le nom de l alerte}" 300 ;;

  *) echo "Test inconnu : $1 (voir: $0 liste)" >&2; exit 2 ;;
esac
