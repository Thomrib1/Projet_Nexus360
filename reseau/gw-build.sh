#!/usr/bin/env bash
# reseau/gw-build.sh : construit ou reconstruit la passerelle LNX-GW0n (rejouable)
# Usage : sudo ./gw-build.sh <n> [fichier_env]     (n = 1 a 5)
set -euo pipefail

N="${1:-}"
ENVFILE="${2:-/root/gw.env}"
[[ "$N" =~ ^[1-5]$ ]] || { echo "Usage : $0 <site 1-5> [gw.env]" >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo "Lance ce script avec sudo" >&2; exit 1; }
[[ -r "$ENVFILE" ]] || { echo "Fichier $ENVFILE introuvable" >&2; exit 1; }
source "$ENVFILE"

# BACKBONE=vmnet  : backbone VMware (VMnet10), routes statiques entre passerelles (defaut)
# BACKBONE=tailnet: pas de carte backbone, les sites sont relies par Tailscale (tailscale0)
BACKBONE="${BACKBONE:-vmnet}"
[[ "$BACKBONE" == "vmnet" || "$BACKBONE" == "tailnet" ]] || { echo "BACKBONE doit valoir vmnet ou tailnet" >&2; exit 1; }
if [[ "$BACKBONE" == "tailnet" ]]; then
  BB_IF="tailscale0"
  BB_MTU="${BB_MTU:-1280}"
fi

LAN_NET="10.36.1${N}.0/24"
LAN_IP="10.36.1${N}.1"
BB_IP="10.36.0.${N}"
LAB_NET="10.36.0.0/16"
BB_MSS=$((BB_MTU - 40))
FQDN="lnx-gw0${N}.ad.nexus360.test"
TAILSCALE="${TAILSCALE:-0}"
log() { echo; echo "==> $*"; }

log "1/9 Paquets et nom d'hote"
dnf -y install nftables tcpdump >/dev/null
hostnamectl set-hostname "$FQDN"

log "2/9 Interfaces reseau (NetworkManager)"
while IFS= read -r c; do
  nmcli con delete "$c" >/dev/null
done < <(nmcli -t -f NAME,TYPE con show | awk -F: '$2=="802-3-ethernet" && $1 !~ /^gw-/ {print $1}')
ensure_con() {
  local name="$1"; shift
  if nmcli -t -f NAME con show | grep -qx "$name"; then nmcli con delete "$name" >/dev/null; fi
  nmcli con add con-name "$name" "$@" >/dev/null
}
ROUTES=""
for m in 1 2 3 4 5; do
  [[ $m -eq $N ]] && continue
  ROUTES+="${ROUTES:+,}10.36.1${m}.0/24 10.36.0.${m}"
done
ensure_con gw-wan type ethernet ifname "$WAN_IF" ipv4.method auto ipv6.method disabled
ensure_con gw-lan type ethernet ifname "$LAN_IF" ipv4.method manual ipv4.addresses "${LAN_IP}/24" ipv6.method disabled
if [[ "$BACKBONE" == "vmnet" ]]; then
  ensure_con gw-bb  type ethernet ifname "$BB_IF"  ipv4.method manual ipv4.addresses "${BB_IP}/24" ipv4.routes "$ROUTES" 802-3-ethernet.mtu "$BB_MTU" ipv6.method disabled
  CONS="gw-wan gw-lan gw-bb"
else
  # Mode tailnet : les routes des autres sites arrivent par Tailscale (--accept-routes)
  nmcli -t -f NAME con show | grep -qx gw-bb && nmcli con delete gw-bb >/dev/null || true
  CONS="gw-wan gw-lan"
fi
for c in $CONS; do nmcli con up "$c" >/dev/null; done

log "3/9 Routage (sysctl)"
cat >/etc/sysctl.d/90-gw.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
EOF
sysctl --system >/dev/null

log "4/9 Pare-feu nftables (NAT, MSS, filtrage)"
systemctl disable --now firewalld 2>/dev/null || true
systemctl mask firewalld 2>/dev/null || true
WAN_SSH_RULE=""
if [[ "${ALLOW_WAN_SSH:-0}" == "1" ]]; then
  WAN_SSH_RULE="    iifname \"${WAN_IF}\" ip saddr ${WAN_ADMIN_NET} tcp dport 22 accept"
fi
TS_RULE=""
if [[ "$TAILSCALE" == "1" ]]; then
  TS_RULE="    iifname \"${WAN_IF}\" udp dport 41641 accept"
fi
install -d -m 0755 /etc/nftables
cat >/etc/nftables/gw.nft <<EOF
# Genere par reseau/gw-build.sh (site ${N}). Ne pas editer a la main.
# On ne vide que nos propres tables, pour ne pas toucher a celles de Tailscale.
table inet gw
delete table inet gw
table ip gw_nat
delete table ip gw_nat

table inet gw {
  chain input {
    type filter hook input priority filter; policy drop;
    ct state invalid drop
    ct state established,related accept
    iif "lo" accept
    icmp type { echo-request, destination-unreachable, time-exceeded } accept
    iifname "${LAN_IF}" tcp dport 22 accept
    iifname "${BB_IF}" ip saddr 10.36.13.22 tcp dport 22 accept
${WAN_SSH_RULE}
${TS_RULE}
    iifname { "${LAN_IF}", "${BB_IF}" } udp dport 67 accept
    iifname "${WAN_IF}" udp sport 67 udp dport 68 accept
    limit rate 5/minute log prefix "gw-in-drop: "
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
    oifname "${BB_IF}" tcp flags & (syn | rst) == syn tcp option maxseg size > ${BB_MSS} tcp option maxseg size set ${BB_MSS}
    ct state invalid drop
    ct state established,related accept
    icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded } accept
    iifname "${LAN_IF}" oifname "${BB_IF}" ip saddr ${LAN_NET} ip daddr ${LAB_NET} accept
    iifname "${BB_IF}" oifname "${LAN_IF}" ip saddr ${LAB_NET} ip daddr ${LAN_NET} accept
    iifname "${LAN_IF}" oifname "${WAN_IF}" ip daddr ${LAB_NET} drop
    iifname "${LAN_IF}" oifname "${WAN_IF}" accept
    limit rate 5/minute log prefix "gw-fwd-drop: "
  }
}
table ip gw_nat {
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "${WAN_IF}" ip saddr ${LAB_NET} masquerade
  }
}
EOF
echo 'include "/etc/nftables/gw.nft"' >/etc/sysconfig/nftables.conf
nft -c -f /etc/nftables/gw.nft
systemctl enable nftables
systemctl restart nftables

log "5/9 Relais DHCP (sites de postes uniquement)"
if [[ " ${DHCP_RELAY_SITES} " == *" ${N} "* ]]; then
  if dnf -y install epel-release >/dev/null && dnf -y install dhcp-relay >/dev/null; then
    cat >/etc/systemd/system/dhcrelay-gw.service <<EOF
[Unit]
Description=Relais DHCP LNX-GW0${N} (${LAN_IF} vers ${DHCP_SERVERS})
After=network-online.target nftables.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/sbin/dhcrelay -d --no-pid -id ${LAN_IF} -iu ${BB_IF} ${DHCP_SERVERS}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now dhcrelay-gw.service
  else
    echo "ATTENTION : paquet dhcp-relay indisponible, relais non installe"
  fi
else
  systemctl disable --now dhcrelay-gw.service 2>/dev/null || true
  echo "pas de relais sur ce site"
fi

log "6/9 SSH durci"
cat >/etc/ssh/sshd_config.d/00-gw-hardening.conf <<EOF
PermitRootLogin no
PubkeyAuthentication yes
AllowGroups wheel
MaxAuthTries 3
EOF
if [[ -s "/home/${ADMIN_USER}/.ssh/authorized_keys" ]]; then
  echo "PasswordAuthentication no" >>/etc/ssh/sshd_config.d/00-gw-hardening.conf
else
  echo "ATTENTION : pas de cle SSH pour ${ADMIN_USER}, mot de passe SSH conserve"
fi
sshd -t && systemctl reload sshd

log "7/9 SELinux enforcing, heure"
setenforce 1 || true
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
systemctl enable --now chronyd

log "8/9 Tailscale (optionnel, TAILSCALE=1)"
if [[ "$TAILSCALE" == "1" ]]; then
  command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
  systemctl enable --now tailscaled
  if [[ "$BACKBONE" == "tailnet" ]]; then
    # Annonce le LAN du site, accepte les routes des autres sites, sans NAT, sans DNS Tailscale
    TS_ARGS=(--hostname="lnx-gw0${N}" --advertise-tags=tag:gw --advertise-routes="${LAN_NET}" \
             --accept-routes --snat-subnet-routes=false --accept-dns=false)
    TS_KEYFILE="${TS_AUTHKEY_FILE:-/root/ts-authkey}"   # cle a usage unique, hors Git, droits 0600
    if [[ -s "$TS_KEYFILE" ]]; then
      tailscale up "${TS_ARGS[@]}" --auth-key="$(cat "$TS_KEYFILE")"
      shred -u "$TS_KEYFILE" 2>/dev/null || rm -f "$TS_KEYFILE"
    else
      echo "Connexion manuelle : sudo tailscale up ${TS_ARGS[*]}"
    fi
  else
    echo "Connexion manuelle : sudo tailscale up --accept-dns=false"
  fi
else
  echo "desactive"
fi

log "9/9 Resume"
echo "gw-build site=${N} date=$(date -Is)" >/etc/gw-build.stamp
ip -br a
ip route
sysctl net.ipv4.ip_forward
systemctl is-active nftables