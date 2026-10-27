# Réseau et postes (site Paris)

Passerelles LNX-GW01 à LNX-GW05, postes CLI-W11-01, CLI-W11-02 et CLI-LNX01, politique d'accès du tailnet.

## Contenu

- `journal.md` : journal d'exploitation
- `gw.env.example` : variables d'une passerelle (copie utilisée : `/root/gw.env`, jamais versionnée)
- `preuves/` : captures et sorties de tests, nommées par exigence
- `tests/`, `dhcp/`, `postes/` : réservés aux phases suivantes

## Environnement du lab

Tout tourne sur VMware Workstation Pro. Les réseaux virtuels sont en host-only, sans DHCP VMware ni carte hôte :

| Réseau | Rôle | Sous-réseau |
|---|---|---|
| VMnet10 | backbone entre les sites (remplace le tailnet) | 10.36.0.0/24 |
| VMnet11 à VMnet15 | LAN des sites 1 à 5 | 10.36.11.0/24 à 10.36.15.0/24 |

Le modèle `GW-TEMPLATE` est une VM Rocky Linux 10.1 minimal à trois cartes (NAT, VMnet11, VMnet10), clonée pour chaque passerelle.

## Construire une passerelle

Prérequis : modèle `GW-TEMPLATE` (Rocky 10.1 minimal, clé SSH installée), `gw.env` adapté depuis `gw.env.example`.

1. Cloner le modèle (clone complet), régler les cartes : NAT, LAN du site, VMnet10.
2. Régénérer l'identité du clone : clés SSH du serveur et `/etc/machine-id`.
3. Copier `gw-build.sh`, `gw.env.example` et `tests/gw-selftest.sh` dans `/tmp`, puis installer dans `/root` (`gw.env` en 0640, scripts en 0750).
4. Depuis la console VMware : `sudo /root/gw-build.sh <n>`.
5. Contrôler : `sudo /root/gw-selftest.sh <n>` doit afficher 14 PASS et 0 FAIL.

## Ordre de démarrage

1. Passerelles LNX-GW0n (attendre environ 60 secondes)
2. Serveurs (DHCP de substitution TMP-DHCP ; DC, serveurs de fichiers et Linux chez les autres rôles)
3. Postes de travail

## DHCP de substitution

`dhcp/kea-substitut.json` sert uniquement à valider le relais DHCP dans le lab. Il sera remplacé par le DHCP des DC.