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

À compléter en phase 3.