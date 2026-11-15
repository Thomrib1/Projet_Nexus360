# Documentation du rôle Identité

SRV-DC01, SRV-DC02, annuaire `ad.nexus360.test`, DNS, DHCP, GPO, comptes à privilèges. Scripts et données : [`windows/identite/`](../../windows/identite/README.md).

| Document | Exigence | Contenu |
|---|---|---|
| [bilan-blocages.md](bilan-blocages.md) | – | **À lire en premier.** Ce qui est fait, ce qui ne l'est pas, pourquoi, et la suite |
| [dat-identite.md](dat-identite.md) | E1, A1 | Architecture, choix techniques justifiés, flux et ports, comptes de service, risques |
| [modele-administration.md](modele-administration.md) | B3 | Trois niveaux T0/T1/T2, comptes nominatifs, délégations, LAPS |
| [matrice-droits.md](matrice-droits.md) | B1 | Groupes AGDLP : qui accède à quoi, par quel groupe |
| [gpo-durcissement.md](gpo-durcissement.md) | B5, B3 | Les 9 GPO, leurs réglages et leur justification |
| [runbook-creer-utilisateur.md](runbook-creer-utilisateur.md) | E2 | Procédure pas à pas |
| [journal.md](journal.md) | D4 | Journal d'exploitation du rôle |
| [preuves/README.md](preuves/README.md) | toutes | Liste des preuves attendues et commandes pour les produire |
| `exports/` | A1, B1, B3, B5, C1 | Sorties texte de `Export-N360Preuves.ps1` et rapports HTML des GPO |
| `preuves/` | toutes | Captures d'écran, nommées par exigence |

## État au 15/11/2026

| | |
|---|---|
| SRV-DC01 | Configuré de bout en bout |
| SRV-DC02 | Préparé, **non promu** : pas de réplication, pas de basculement DHCP |
| Machines jointes au domaine | 2 sur 9 : LNX-OPS01, LNX-WEB01 |
| Preuves versées | Aucune pour l'instant |
