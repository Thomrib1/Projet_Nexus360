<!-- markdownlint-disable MD060 -->
# Journal d'exploitation, rôle Réseau et postes

| Date et heure | Machine | Action | Résultat | Preuve |
|---|---|---|---|---|
| 2026-10-22 14:00 | PC hôte | Vérification VMware, RAM, disque | à compléter | - |

| 2026-10-22 21:03 | PC hôte | Création VMnet10 à VMnet15 (host-only, sans DHCP, sans carte hôte) | OK | preuves/phase1-vmnet-editeur.png |
| 2026-10-22 21:04 | PC hôte | Sous-réseau VMnet8 relevé : 192.168.157.0/24 | OK | - |

| 2026-10-22 23:32 | GW-TEMPLATE | Installation Rocky 10.1 minimal, mises à jour, paquets, test des interfaces ens160 ens192 ens224 | OK | - |
| 2026-10-22 23:33 | PC hôte | Clé SSH id_nexus360 créée, connexion par clé testée sur GW-TEMPLATE | OK | - |
| 2026-10-22 23:34 | GW-TEMPLATE | Snapshot template-propre | OK | - |

| 2026-10-24 21:45 | LNX-GW04 | Relais DHCP dhcrelay-gw actif vers 10.36.11.10 et 10.36.12.11 | OK | preuves/A8-gw04-relais-dhcp.png |

| 2026-10-25 00:00 | LNX-GW01 | Clone, identité régénérée, gw-build.sh 1 (deux exécutions) | OK | preuves/A8-gw01-build-run1.png, preuves/A8-gw01-build-run2.png |
| 2026-10-25 00:01 | LNX-GW01 | gw-selftest.sh 1 : 14 PASS, 0 FAIL | OK | preuves/A8-selftest-gw01.png |
| 2026-10-25 00:02 | LNX-GW01 / LNX-GW04 | Ping du backbone et routage entre les sites 1 et 4 | OK | preuves/A8-gw01-gw04-routage.png |
| 2026-10-25 00:03 | LNX-GW01 | Snapshot gw-ok | OK | preuves/A8-gw01-snapshot.png |
