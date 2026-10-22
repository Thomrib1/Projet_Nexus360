<!-- markdownlint-disable MD060 -->
# Journal d'exploitation, rôle Réseau et postes

| Date et heure | Machine | Action | Résultat | Preuve |
|---|---|---|---|---|
| 2026-10-22 14:00 | PC hôte | Vérification VMware, RAM, disque | à compléter | - |

| 2026-10-22 hh:mm | PC hôte | Création VMnet10 à VMnet15 (host-only, sans DHCP, sans carte hôte) | OK | preuves/phase1-vmnet-editeur.png |
| 2026-10-22 21:04 | PC hôte | Sous-réseau VMnet8 relevé : 192.168.157.0/24 | OK | - |

| 2026-10-22 23:32 | GW-TEMPLATE | Installation Rocky 10.1 minimal, mises à jour, paquets, test des interfaces ens160 ens192 ens224 | OK | - |
| 2026-10-22 23:33 | PC hôte | Clé SSH id_nexus360 créée, connexion par clé testée sur GW-TEMPLATE | OK | - |
| 2026-10-22 23:34 | GW-TEMPLATE | Snapshot template-propre | OK | - |
