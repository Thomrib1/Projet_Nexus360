# DAT – Réseau et postes (rôle 5) – Nexus360 T01

Auteur : Benor (Mathys) · Périmètre : passerelles LNX-GW01..05, accès Tailscale, postes CLI-W11-01 / CLI-W11-02 / CLI-LNX01.

## 1. Vue d'ensemble

```
                    Backbone VMnet10 – 10.36.0.0/24 (MTU 1280, remplace le tailnet)
   ┌───────────┬───────────┬───────────┬───────────┬───────────┐
 GW01 .1     GW02 .2     GW03 .3     GW04 .4     GW05 .5
 LAN VMnet11 LAN VMnet12 LAN VMnet13 LAN VMnet14 LAN VMnet15
 10.36.11/24 10.36.12/24 10.36.13/24 10.36.14/24 10.36.15/24
 (site 1)    (site 2)    (site 3)    (site 4)    (site 5)
                                      │ relais DHCP  │ relais DHCP
                                      │ → 10.36.11.10 / 10.36.12.11
                               CLI-W11-01/02, CLI-LNX01 (postes)
 WAN : VMnet8 NAT 192.168.157.0/24 (ens160 de chaque passerelle)
```

## 2. Plan d'adressage

| Passerelle | WAN (ens160) | LAN (ens192) | Backbone (ens224) |
|---|---|---|---|
| LNX-GW01 | DHCP NAT | 10.36.11.1 | 10.36.0.1 |
| LNX-GW02 | DHCP NAT | 10.36.12.1 | 10.36.0.2 |
| LNX-GW03 | DHCP NAT | 10.36.13.1 | 10.36.0.3 |
| LNX-GW04 | DHCP NAT | 10.36.14.1 | 10.36.0.4 |
| LNX-GW05 | DHCP NAT | 10.36.15.1 | 10.36.0.5 |

Routes statiques : `10.36.1m.0/24 via 10.36.0.m` sur chaque passerelle pour les autres sites.

Postes (sites 4 et 5) : pool DHCP .110–.200 ; réservations par MAC (CLI-W11-01 → 10.36.14.101, CLI-W11-02 → 10.36.14.102).

## 3. Flux et ports

| Flux | Source → Destination | Port | Traitement |
|---|---|---|---|
| Inter-sites | LAN n → LAN m | tous | routé, sans NAT |
| Internet | LAN → WAN | tous | masquerade uniquement vers WAN |
| LAN → WAN vers 10.36.0.0/16 | – | – | drop (pas de fuite) |
| DHCP | poste → GW (relais) → serveur DHCP | UDP 67/68 | dhcrelay, giaddr = IP LAN GW |
| Administration | WAN_ADMIN_NET → GW | TCP 22 | clé SSH uniquement |
| Tailscale (optionnel) | GW ↔ Internet | UDP 41641 | si TAILSCALE=1 |

## 4. Choix techniques

- **nftables** (tables `inet gw` et `ip gw_nat`) : le script ne supprime que ses tables, celles de Tailscale restent.
- **Backbone VMware VMnet10** à la place d'un tailnet commun : le partage de nœuds Tailscale n'expose ni les sous-réseaux ni les tags.
- **MTU 1280 / MSS 1240** (1280-40) : clamp MSS pour simuler la contrainte Tailscale ; prouvé par tcpdump.
- **dhcrelay** (paquet EPEL dhcp-relay) sur les sites 4 et 5 vers les serveurs DHCP des sites 1 et 2.
- **Kea DHCP de substitution** (TMP-DHCP 10.36.11.10) tant que les vrais DC ne servent pas le DHCP.
- **Durcissement** : SSH par clé + groupe wheel, SELinux enforcing, chrony, firewalld arrêté (nftables seul).
- **Reconstruction** : `sudo ./gw-build.sh <1-5>` avec `/root/gw.env` (jamais versionné).

## 5. Tailscale et politique ACL

Fichier `tailnet-policy.hujson` : tags `tag:gateway`, hôtes des sites, autoApprovers des routes, ACL sites↔sites, accès partagé limité (bastion:22, srv-mgt01 RDP/WinRM), et **tests** (accept dc01:445 et mon01:9090 depuis un poste ; deny 8.8.8.8:53). Aucune adresse e-mail dans le fichier. À réécrire (tag:gw, UDP 67, ports AD) si un tailnet commun est adopté.

## 6. Postes

| Poste | OS | OU cible |
|---|---|---|
| CLI-W11-01 | Windows 11 Pro | OU=Windows,OU=Postes,OU=NEXUS360,DC=ad,DC=nexus360,DC=test |
| CLI-W11-02 | Windows 11 Pro | OU=Pilote,OU=Postes,OU=NEXUS360,… |
| CLI-LNX01 | Ubuntu 26.04 LTS Desktop (NetworkManager, SSSD) | OU=Linux,OU=Postes,OU=NEXUS360,… |

Identifiant DHCP basé sur la MAC (`dhcp-identifier: mac`) pour que les réservations soient stables. Jonction avec le compte de service `svc-adjoin` (mot de passe jamais dans Git).

## 7. Dérogations, risques, limites

- Tailscale remplacé par un backbone VMware (documenté ci-dessus).
- Une seule passerelle par site (pas de redondance).
- `ALLOW_WAN_SSH=1` pendant le projet ; à passer à 0 avant le gel.
- TMP-DHCP temporaire : à retirer quand les DC servent le DHCP.
- CLI-W10-01 (Win10 Famille) : VM de test, non livrée (ne peut pas joindre le domaine).
- Synchro chrony non vérifiable sans DC ; jonction et partages (A2/A5) en attente du DC et de `svc-adjoin` ; règle 2 de l'ACL non prouvée tant que les pairs sont hors ligne ; test de bascule DHCP (C4) en attente.
- Reconstruction mesurée ~51 min avec pauses.

## 8. Preuves

Dossier `reseau/preuves/` : A8-* (passerelles, relais, MTU/MSS), A2-* (postes), B5-* (durcissement/ACL), C4-* (ordre de démarrage), E3-* (PR).
