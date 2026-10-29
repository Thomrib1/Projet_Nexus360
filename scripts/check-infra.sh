#!/usr/bin/env bash
# =============================================================================
# check-infra.sh — Bilan de l'infrastructure Nexus360, DANS L'ORDRE DE DÉMARRAGE (exigence C4)
#
# Propriétaire : rôle 4 (Exploitation)
# Exécuté sur  : LNX-OPS01 (bastion, VM du PC du rôle 3), par un membre ou par le pipeline
# Dépend de    : rôle 3 (OPS01 installé, SSSD, chrony), rôle 5 (passerelles + tailnet entre les PC),
#                rôle 1 (DNS/AD), rôle 4 (supervision sur LNX-MON01)
# Chaque ligne indique le PC qui héberge la machine et le rôle à prévenir en cas d'échec.
#
#   bash scripts/check-infra.sh            # bilan détaillé
#   bash scripts/check-infra.sh --court    # uniquement les échecs + le résumé
# Code retour : 0 si tout est OK, 1 sinon. Dépendances : bash, coreutils, curl, dig, jq.
# =============================================================================
set -uo pipefail
# shellcheck source=scripts/nexus.env
source "$(dirname "$0")/nexus.env"

COURT=0; [[ "${1:-}" == "--court" ]] && COURT=1
ok=0; ko=0

vert=$'\e[32m'; rouge=$'\e[31m'; gras=$'\e[1m'; raz=$'\e[0m'
[[ -t 1 ]] || { vert=; rouge=; gras=; raz=; }

etape() { (( COURT )) || printf '\n%s== %s ==%s\n' "$gras" "$1" "$raz"; }
res()   { # $1 = libellé ; le reste = commande
  local lib="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok=$((ok + 1)); (( COURT )) || printf '  %s[OK]%s   %s\n' "$vert" "$raz" "$lib"
  else
    ko=$((ko + 1)); printf '  %s[ÉCHEC]%s %s\n' "$rouge" "$raz" "$lib"
  fi
}
tcp()   { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" ; }
dns()   { [[ -n "$(dig +short +time=2 +tries=1 @"$1" "$2" "${3:-A}")" ]]; }

etape "1. Passerelles et tailnet (une par PC — rôle 5 ; démarrent en premier)"
n=1
for gw in $GATEWAYS; do
  res "LNX-GW0$n ($gw) — PC rôle $n, config rôle 5" ping -c1 -W2 "$gw"; n=$((n + 1))
done

etape "2. Contrôleurs de domaine (rôle 1)"
res "SRV-DC01 DNS (SRV _ldap._tcp) — PC rôle 1"  dns "$DC1" "_ldap._tcp.$DOMAIN" SRV
res "SRV-DC01 LDAP 389 / Kerberos 88"           bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/$DC1/389' && timeout 3 bash -c 'exec 3<>/dev/tcp/$DC1/88'"
res "SRV-DC02 DNS (SRV _ldap._tcp) — PC rôle 2"  dns "$DC2" "_ldap._tcp.$DOMAIN" SRV
res "SRV-DC02 LDAP 389 / Kerberos 88"           bash -c "timeout 3 bash -c 'exec 3<>/dev/tcp/$DC2/389' && timeout 3 bash -c 'exec 3<>/dev/tcp/$DC2/88'"
res "Alias intranet résolu par les deux DC"     bash -c "dig +short @$DC1 intranet.$DOMAIN | grep -q . && dig +short @$DC2 intranet.$DOMAIN | grep -q ."

etape "3. Serveurs Windows membres (rôle 2 — PC rôle 2)"
res "SRV-FS01 SMB 445"                    tcp "$FS" 445
res "SRV-MGT01 WinRM 5985"                tcp "$MGT" 5985
res "SRV-MGT01 SSH 22 (déploiement CI)"   tcp "$MGT" 22

etape "4. Serveurs Linux (rôle 3 — PC rôle 3 ; MON01 rôle 4 — PC rôle 4)"
res "LNX-WEB01 HTTP 80"                   tcp "$WEB" 80
res "Intranet affiche un identifiant de commit" bash -c "curl -fsS -m5 http://intranet.$DOMAIN | grep -Eq '[0-9a-f]{7,40}'"
res "LNX-APP01 SSH 22"                    tcp "$APP" 22
res "LNX-MON01 rsyslog 514"               tcp "$MON" 514
res "LNX-OPS01 /srv/backup monté"         mountpoint -q /srv/backup
res "LNX-OPS01 RAID 1 sain"               bash -c "! grep -A1 '^md' /proc/mdstat | grep -o '\[[U_]*\]' | grep -q '_'"
res "Heure synchronisée sur les DC (chrony)" bash -c "chronyc tracking | grep -q 'Leap status *: Normal'"
res "Authentification AD (SSSD) : getent d'un compte du domaine" bash -c "getent passwd \"administrateur@$DOMAIN\" || getent passwd \"administrator@$DOMAIN\""

etape "5. Supervision (rôle 4 — doit montrer que TOUT est revenu)"
res "Prometheus prêt"   curl -fsS -m5 "http://$MON:9090/-/ready"
res "Alertmanager prêt" curl -fsS -m5 "http://$MON:9093/-/ready"
res "Grafana prêt"      curl -fsS -m5 "http://$MON:3000/api/health"
if down=$(curl -fsS -m5 "http://$MON:9090/api/v1/query" --data-urlencode 'query=up{job=~"linux|windows"} == 0' 2>/dev/null); then
  liste=$(printf '%s' "$down" | jq -r '.data.result[].metric.instance' 2>/dev/null | paste -sd, -)
  res "Toutes les cibles collectées${liste:+ (en panne : $liste)}" test -z "$liste"
  alertes=$(curl -fsS -m5 "http://$MON:9093/api/v2/alerts?active=true&silenced=false" | jq -r '.[].labels.alertname' 2>/dev/null | sort | uniq -c | paste -sd, -)
  res "Aucune alerte active${alertes:+ (actives : $alertes)}" test -z "$alertes"
fi
res "Journaux de LNX-WEB01 reçus sur MON01 depuis moins de 15 min" \
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$MON" "find /var/log/remote/lnx-web01 -mmin -15 -type f | grep -q ."

printf '\n%sBilan : %d OK, %d échec(s)%s\n' "$gras" "$ok" "$ko" "$raz"
(( ko == 0 ))
