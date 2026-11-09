# Runbooks – Réseau et postes

## RB1 – Ordre de démarrage
1. Passerelles LNX-GW01..05 (attendre le login).
2. Serveurs, dont **TMP-DHCP (10.36.11.10)** : doit être allumé avant tout poste.
3. Postes CLI-*.
Vérif : sur chaque GW `sudo ./tests/gw-selftest.sh` → `14 PASS / 0 FAIL`.
Preuve : `C4-ordre-demarrage.png`.

## RB2 – Reconstruire une passerelle
1. Installer Rocky 10.1 minimal, 3 NIC (ens160 WAN, ens192 LAN, ens224 backbone), utilisateur admin + clé SSH.
2. Cloner le dépôt, copier `reseau/gw.env.example` vers `/root/gw.env`, l'adapter (jamais versionné).
3. `sudo ./gw-build.sh <n>` (n = 1..5).
4. `sudo ./tests/gw-selftest.sh` → 14 PASS.
Preuve : `A8-gwNN-build-run2.png`, `A8-selftest-gwNN.png`.

## RB3 – Ajouter un poste
1. Créer la VM sur le VMnet du site (11–15).
2. Relever la MAC ; ajouter la réservation dans Kea (puis DC) ; recharger.
3. Windows : `Add-Computer -DomainName ad.nexus360.test -OUPath "<OU>" -Credential svc-adjoin` ; Ubuntu : `realm join` + SSSD.
4. Tester : IP attendue, DNS, accès partage.
Preuve : `A2-<poste>-ip.png`, `A2-<poste>-jonction.png`.

## RB4 – DHCP ne répond pas aux postes
1. TMP-DHCP allumée ? `systemctl status kea-dhcp4`.
2. Relais actif sur la GW : `systemctl status dhcrelay-gw`.
3. `journalctl -u kea-dhcp4` : présence de la requête avec giaddr 10.36.14.1 / 10.36.15.1.
4. Renouveler le bail côté poste.

## RB5 – Avant le gel (veille de la session 6, 23:59)
- `ALLOW_WAN_SSH=0` dans `gw.env.example`.
- Répétition de reconstruction chronométrée.
- Journal complet, PR fusionnées, tag `v1.0`.
