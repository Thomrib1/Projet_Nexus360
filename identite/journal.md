# Journal d'exploitation, rôle Identité (D4)

Une ligne par action, la plus récente en bas : date et heure réelles, machine, action, résultat, preuve.
Même format que `reseau/journal.md`.

> **À compléter par Thomas.** Les lignes datées ci-dessous viennent de sorties observées (journaux `dcpromo.log`, fichier d'import, `realm list`).
> Les lignes « date à relever » décrivent des actions faites dont l'heure exacte est dans `C:\N360\logs\<script>-<date>.log` sur SRV-DC01.
> Ne pas inventer une heure : reporter celle du journal du script, ou laisser « non relevée ».

| Date et heure | Machine | Action | Résultat | Preuve |
|---|---|---|---|---|
| 2026-10-20 | Dépôt Git | Création du dépôt `Projet_Nexus360` (premier commit) | OK | historique Git, commit `5be8816` |
| date à relever | SRV-DC01 | Installation de Windows Server 2025 (bureau), adresse 10.36.11.10/24 | OK | à verser |
| date à relever | SRV-DC01 | Promotion : forêt créée avec le nom `ad.nexus360` au lieu de `ad.nexus360.test` | **Erreur** | à verser |
| date à relever | SRV-DC01 | Rétrogradation, puis nouvelle promotion avec le nom `ad.nexus360.test` (NetBIOS `NEXUS360`) | OK | `exports/A1-domaine.txt` |
| date à relever | SRV-DC01 | 5 sites AD (SITE1 à SITE5), sous-réseaux 10.36.11.0/24 à 10.36.15.0/24, liens de sites | OK | `exports/A1-sites.txt` |
| date à relever | SRV-DC01 | DNS : zones inverses, redirecteurs 1.1.1.1 et 9.9.9.9, enregistrements des serveurs, alias `intranet` | OK | `exports/A1-dns-*.txt` |
| date à relever | SRV-DC01 | 33 unités d'organisation sous `OU=NEXUS360` (créées à la console) | OK | `exports/B1-ou.txt` |
| date à relever | SRV-DC01 | Groupes `GG_*` et `DL_*` (AGDLP) | OK | `exports/B1-groupes.txt` |
| 2026-11-09 12:02 | SRV-DC01 | 7 comptes d'administration `t0-*`, `t1-*`, `t2-*` et compte de service `svc-adjoin` ; mots de passe générés, hors dépôt | OK | `exports/B3-comptes-admin.txt` |
| 2026-11-09 12:03 | SRV-DC01 | Import de 17 utilisateurs depuis `users.csv` ; changement de mot de passe exigé à la première connexion | OK | `exports/B1-utilisateurs.txt` |
| date à relever | SRV-DC01 | PSO `PSO-Comptes-Privilegies` et `PSO-Comptes-Service` | OK | `exports/B3-pso.txt` |
| date à relever | SRV-DC01 | Délégations (gestion des comptes, réinitialisation de mot de passe, jonction) | OK | `exports/B3-delegations.txt` |
| date à relever | SRV-DC01 | LAPS : première simulation en échec (attribut `ms-LAPS-Password` introuvable), puis extension du schéma et droits de lecture par niveau | OK après correction | `exports/B3-laps.txt` |
| date à relever | SRV-DC01 | 9 GPO `N360-*` créées et liées | OK | `exports/gpo/` |
| date à relever | SRV-DC01 | Heure : PDC synchronisé sur `fr.pool.ntp.org` | OK | `exports/A1-heure.txt` |
| date à relever | SRV-DC01 | Récupération automatique des services critiques | OK | `exports/C1-services.txt` |
| date à relever | SRV-DC01 | DHCP : erreur `NameProtection` (paramètres DNS appliqués dans le mauvais ordre), script corrigé ; étendues `POSTES-SITE4` et `POSTES-SITE5`, réservations par MAC | OK après correction | `exports/A1-dhcp.txt` |
| 2026-11-09 | SRV-DC02 | Promotion, essai 1 : résolution de `_ldap._tcp.dc._msdcs` expirée. Aucun routage entre les sites | **Échec** | à verser |
| date à relever | LNX-GW01 | Passerelle du site 1 montée sur le PC de Thomas (construction 9/9) ; depuis DC01 : ping de 10.36.11.1, route 10.36.0.0/16 posée | OK | à verser |
| 2026-11-10 00:54 | SRV-DC02 | Promotion, essai 2 : « Site AD SITE2 introuvable ». Identifiants du domaine vides dans la session distante | **Échec** | à verser |
| 2026-11-10 01:04 | SRV-DC02 | Promotion, essai 3 : lancée depuis une session distante | En cours | à verser |
| 2026-11-10 01:46 | SRV-DC02 | Essai 3 : erreur 1722 « The RPC server is unavailable » vers SRV-DC01 (`dcpromo.log`, 01:46:53). `NTDS` et `Netlogon` arrêtés | **Échec** | `preuves/A1-dc02-dcpromo-1722.txt` |
| 2026-11-10 02:14 | SRV-DC02 | Promotion, essai 4 : lancement local sans identifiants du domaine ; DC01 rejette le compte local | **Échec** | à verser |
| 2026-11-10 | SRV-DC01 | `Get-ADDomainController` affiche DC01 avec l'adresse Tailscale 100.x : la carte Tailscale et la carte NAT s'enregistrent dans le DNS | **Anomalie** | à verser |
| date à relever (au plus tard le 10/11) | SRV-DC01 | Contrôle `Test-N360Identity.ps1` : 47 OK, 12 ECHEC, 8 ALERTE (échecs liés à l'absence de DC02) | OK | `preuves/A1-test-identite.txt` |
| 2026-11-10 10:49 | SRV-DC02 | Promotion, essai 5 : `dcpromo.log` n'avance plus ; à 11:21, aucun objet `NTDS Settings` sous SITE2 sur DC01 | **Échec** | à verser |
| 2026-11-10 | LNX-MON01 | Jonction au domaine à travers LNX-GW02 : `realm list` affiche `kerberos-member` | OK | à verser |
| 2026-11-12 | Tailnet | LNX-GW02 apparaît « Shared in » dans la console : nœud partagé, ses routes ne sont pas reçues | **Anomalie** | à verser |
| date à relever | SRV-DC01 | DNS : enregistrement désactivé sur les cartes Tailscale et NAT, enregistrements 100.x supprimés, écoute limitée à 10.36.11.10 | à confirmer | `exports/A1-dns-dc01.txt` |
| date à relever (12 ou 13/11) | LNX-OPS01 | Jonction au domaine avec `svc-adjoin`, OU `Serveurs/Linux` ; `id svc-adjoin@ad.nexus360.test` renvoie `dl_t1_jonction` et `dl_t2_jonction` | OK | `preuves/A2-lnx-ops01-realm.txt` |
| 2026-11-13 | SRV-DC01 | Enregistrements DNS `lnx-web01` (10.36.13.21) et `lnx-ops01` (10.36.13.22) créés | OK | `exports/A1-dns-enregistrements.txt` |
| 2026-11-13 | SRV-DC01 | `Test-NetConnection 10.36.12.11 -Port 5985` : échec. Reconfiguration à distance de DC02 impossible | **Échec** | à verser |
| date à relever | LNX-WEB01 | Jonction au domaine depuis le bastion LNX-OPS01 | OK (déclaré) | `preuves/A2-lnx-web01-realm.txt` |
| 2026-11-15 | SRV-DC01 | LNX-GW02 membre du tailnet commun ; port 5985 de DC02 joignable depuis DC01 | OK (déclaré) | à verser |

## Utilisations du compte Administrateur intégré

B3 demande que ce compte ne serve plus au quotidien. Chaque utilisation doit apparaître ici.

| Date | Machine | Raison |
|---|---|---|
| mise en place (dates à relever) | SRV-DC01 | Promotion et amorçage de l'annuaire, avant la création des comptes `t0-*` |
| 2026-11-10 | SRV-DC02 | Tentatives de promotion (`NEXUS360\Administrateur`) |
