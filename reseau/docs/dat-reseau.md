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

Postes : pool DHCP .110–.200 sur les sites 4 et 5 ; réservations par MAC sur le site 4 (CLI-W11-01 → 10.36.14.101, CLI-LNX01 → 10.36.14.102). CLI-W11-02 est sur le site 5 (VMnet15).

## 3. Flux et ports

| Flux | Source → Destination | Port | Traitement |
|---|---|---|---|
| Inter-sites | LAN n → LAN m | tous | routé, sans NAT |
| Internet | LAN → WAN | tous | masquerade uniquement vers WAN |
| LAN → WAN vers 10.36.0.0/16 | – | – | drop (pas de fuite) |
| DHCP | poste → GW (relais) → serveur DHCP | UDP 67/68 | dhcrelay, giaddr = IP LAN GW |
| Administration | WAN_ADMIN_NET → GW | TCP 22 | clé SSH uniquement |
| Tailscale (mode tailnet) | GW ↔ Internet | UDP 41641 | si TAILSCALE=1 |

## 4. Choix techniques

- **nftables** (tables `inet gw` et `ip gw_nat`) : le script ne supprime que ses tables, celles de Tailscale restent.
- **Backbone VMware VMnet10** pour le lab local ; **mode tailnet** pour la liaison réelle entre les PC du groupe (le partage de nœuds Tailscale n'expose ni les sous-réseaux ni les tags, d'où un tailnet commun avec `tag:gw`).
- **MTU 1280 / MSS 1240** (1280-40) : clamp MSS pour simuler la contrainte Tailscale ; prouvé par tcpdump.
- **dhcrelay** (paquet EPEL dhcp-relay) sur les sites 4 et 5 vers les serveurs DHCP des sites 1 et 2.
- **Kea DHCP de substitution** (TMP-DHCP 10.36.11.10) tant que les vrais DC ne servent pas le DHCP.
- **Durcissement** : SSH par clé + groupe wheel, SELinux enforcing, chrony, firewalld arrêté (nftables seul).
- **Reconstruction** : `sudo ./gw-build.sh <1-5>` avec `/root/gw.env` (jamais versionné).

## 5. Tailscale et politique ACL

Deux modes de liaison entre sites, choisis par `BACKBONE` dans `gw.env` :

| Mode | Liaison inter-sites | Usage |
|---|---|---|
| `vmnet` (défaut) | VMnet10 10.36.0.0/24, routes statiques | lab sur le PC de Benor |
| `tailnet` | `tailscale0`, passerelles = routeurs de sous-réseau (`tag:gw`) | tailnet commun du groupe |

En mode `tailnet` : `tailscale up --hostname=lnx-gw0N --advertise-tags=tag:gw --advertise-routes=<LAN du site> --accept-routes --snat-subnet-routes=false --accept-dns=false`. Pas de NAT entre sites, MSS clamp 1240 sur `tailscale0`. Seules les passerelles ont Tailscale ; les VM n'en ont pas. Règle d'hébergement : une passerelle tourne sur le même VMnet que son DC (GW01 chez Thomas, GW02 chez Dilan). Le préfixe 10.36.0.0/24 n'est jamais annoncé.

Fichier `tailnet-policy.hujson` (collé une fois dans la console du tailnet commun, Git sert de référence) : tag `tag:gw` (propriétaire `autogroup:admin`), hôtes des sites, **autoApprovers** des routes 10.36.11–15.0/24 pour `tag:gw`, ACL passerelles↔passerelles, ports AD entre sites (53, 67, 88, 123, 135, 389, 445, 464, 636, 3268, 5985, 9389, 49152-65535), supervision (mon01:9090), ICMP, accès des machines partagées limité à bastion:22 et srv-mgt01 (3389, 5985, 5986). Les **tests** de la politique (DC02→DC01 sur les ports AD, poste site 4→DC et supervision, refus de 8.8.8.8:53 et dc01:3389) sont évalués à chaque enregistrement. Aucune adresse e-mail dans le fichier.

Clés de connexion : usage unique, 1 jour, tag `tag:gw`, transmises en privé, jamais versionnées (`/root/ts-authkey`, 0600, supprimée par le script).

## 6. Postes

| Poste | Site / MAC | OS | OU cible |
|---|---|---|---|
| CLI-W11-01 | Site 4, 00:50:56:2E:14:01, 10.36.14.101 | Windows 11 Pro | OU=Windows,OU=Postes,OU=NEXUS360,DC=ad,DC=nexus360,DC=test |
| CLI-W11-02 | Site 5, 00:50:56:2E:15:01, DHCP, bail 10.36.15.110 | Windows 11 Pro | OU=Pilote,OU=Postes,OU=NEXUS360,… |
| CLI-LNX01 | Site 4, 00:50:56:2E:14:02, 10.36.14.102 | Ubuntu 26.04 LTS Desktop (NetworkManager, SSSD) | OU=Linux,OU=Postes,OU=NEXUS360,… |

Identifiant DHCP basé sur la MAC (`dhcp-identifier: mac`) pour que les réservations soient stables. Jonction avec le compte de service `svc-adjoin` (mot de passe jamais dans Git).

## 7. Dérogations, risques, limites

- Lab local sur backbone VMware ; liaison inter-PC par tailnet commun (GW01 chez Thomas, GW02 chez Dilan, hors tailnet côté Benor pour ne pas annoncer deux fois la même route).
- Une seule passerelle par site (pas de redondance).
- `ALLOW_WAN_SSH=1` pendant le projet ; à passer à 0 avant le gel.
- TMP-DHCP temporaire : à retirer quand les DC servent le DHCP.
- CLI-W10-01 (Win10 Famille) : VM de test, non livrée (ne peut pas joindre le domaine).
- Synchro chrony non vérifiable sans DC ; jonction et partages (A2/A5) en attente du DC et de `svc-adjoin` ; règle 5 de l'ACL (machines partagées) non prouvée tant que les pairs sont hors ligne ; test de bascule DHCP (C4) en attente.
- Reconstruction mesurée ~51 min avec pauses.

## 8. Preuves

Dossier `reseau/preuves/` : A8-* (passerelles, relais, MTU/MSS), A2-* (postes), B5-* (durcissement/ACL), C4-* (ordre de démarrage), E3-* (PR).
