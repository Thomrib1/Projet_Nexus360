#!/usr/bin/env bash
# Usage : sudo ./gw-selftest.sh <n>
N="${1:?numero de site}"
source /root/gw.env
ok=0; ko=0
t() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS  $d"; ok=$((ok+1)); else echo "FAIL  $d"; ko=$((ko+1)); fi; }
t "ip_forward actif"            test "$(sysctl -n net.ipv4.ip_forward)" = 1
t "SELinux enforcing"           test "$(getenforce)" = Enforcing
t "firewalld arrete"            bash -c '! systemctl is-active --quiet firewalld'
t "nftables actif"              systemctl is-active --quiet nftables
t "masquerade present"          bash -c 'nft list ruleset | grep -q masquerade'
t "IP LAN 10.36.1${N}.1"        bash -c "ip -4 -o a show dev $LAN_IF | grep -q 10.36.1${N}.1/24"
t "IP backbone 10.36.0.${N}"    bash -c "ip -4 -o a show dev $BB_IF | grep -q 10.36.0.${N}/24"
t "MTU backbone = $BB_MTU"      test "$(cat /sys/class/net/$BB_IF/mtu)" = "$BB_MTU"
for m in 1 2 3 4 5; do
  [[ $m -eq $N ]] && continue
  t "route site $m via 10.36.0.$m" bash -c "ip route | grep -q '10.36.1$m.0/24 via 10.36.0.$m'"
done
t "Internet (ping 1.1.1.1)"     ping -c1 -W2 1.1.1.1
t "SSH par cle uniquement"      bash -c "grep -q 'PasswordAuthentication no' /etc/ssh/sshd_config.d/00-gw-hardening.conf"
echo "--- $ok PASS / $ko FAIL"
[[ $ko -eq 0 ]]