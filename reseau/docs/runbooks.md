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
3. Régénérer l'identité du clone : `sudo rm -f /etc/machine-id` puis `sudo systemd-machine-id-setup` (si le fichier est absent, passer directement à la seconde commande), et les clés SSH du serveur.
4. `sudo ./gw-build.sh <n>` (n = 1..5).
5. `sudo ./tests/gw-selftest.sh <n>` → 14 PASS.
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

## RB6 – Passerelle en mode tailnet
1. `gw.env` : `BACKBONE=tailnet`, `TAILSCALE=1` (modèle `gw.env.tailnet.example`).
2. Clé tag:gw (usage unique, 1 jour) reçue en privé → `/root/ts-authkey`, droits 0600.
3. `sudo ./gw-build.sh <n> /root/gw.env` puis `sudo ./tests/gw-selftest.sh <n>`.
4. Console Tailscale : `lnx-gw0<n>` taguée `tag:gw`, route du site approuvée. Sinon : vérifier que la clé porte bien le tag et que la politique est enregistrée.
5. Test : depuis un hôte d'un autre site, `Test-NetConnection <IP> -Port 53`.
Preuve : `B5-tailnet-machines-tag-gw.png`, `A8-gwNN-tailnet-selftest.png`.

## RB7 – Clé Tailscale expirée ou perdue
1. Console, Settings, Keys : révoquer l'ancienne clé.
2. Générer une nouvelle clé (Reusable et Ephemeral désactivés, tag:gw, 1 jour).
3. L'envoyer en privé ; ne jamais la coller dans Git, le journal ou une capture.
