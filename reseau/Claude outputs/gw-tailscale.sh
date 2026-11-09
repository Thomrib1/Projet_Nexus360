#!/bin/bash
# Relie une passerelle au tailnet commun (à lancer APRÈS gw-build.sh).
# Usage : sudo ./gw-tailscale.sh <1-5>
# Variable : TS_AUTHKEY (clé à usage unique fournie hors Git) ; sinon connexion interactive.
set -euo pipefail

SITE="${1:?usage: $0 <1-5>}"
[[ "$SITE" =~ ^[1-5]$ ]] || { echo "site invalide"; exit 1; }
LAN_IF="${LAN_IF:-ens192}"
SUBNET="10.36.1${SITE}.0/24"
TS_IF="tailscale0"

[ -f /root/gw.env ] && source /root/gw.env

echo "[1/5] Paquet Tailscale"
if ! command -v tailscale >/dev/null; then
  dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/10/tailscale.repo
  dnf -y install tailscale
fi
systemctl enable --now tailscaled

echo "[2/5] Ouverture UDP 41641 (WireGuard direct)"
nft list table inet gw_ts >/dev/null 2>&1 && nft delete table inet gw_ts || true

echo "[3/5] Connexion : ${SUBNET} annoncé, routes des autres sites acceptées, sans NAT"
UP_ARGS=(--hostname="lnx-gw0${SITE}" --advertise-tags=tag:gw
         --advertise-routes="${SUBNET}" --accept-routes --snat-subnet-routes=false)
if [ -n "${TS_AUTHKEY:-}" ]; then
  tailscale up "${UP_ARGS[@]}" --auth-key="${TS_AUTHKEY}"
else
  tailscale up "${UP_ARGS[@]}"
fi

echo "[4/5] Pare-feu : LAN <-> tailscale0 sans NAT, MSS clampé"
cat > /etc/nftables/gw-ts.nft <<EOF
table inet gw_ts {
  chain forward {
    type filter hook forward priority -10; policy accept;
    iifname "${LAN_IF}" oifname "${TS_IF}" accept
    iifname "${TS_IF}" oifname "${LAN_IF}" accept
    oifname "${TS_IF}" tcp flags syn tcp option maxseg size set rt mtu
  }
}
EOF
nft -f /etc/nftables/gw-ts.nft
grep -q "gw-ts.nft" /etc/sysconfig/nftables.conf 2>/dev/null || \
  echo 'include "/etc/nftables/gw-ts.nft"' >> /etc/sysconfig/nftables.conf
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo "[5/5] Contrôle"
tailscale status | head -n 8
ip route | grep -E "10\.36\." || true
echo "OK : approuver les routes si la politique n'a pas encore autoApprovers."
