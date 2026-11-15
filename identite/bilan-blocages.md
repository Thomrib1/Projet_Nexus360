# Rôle Identité : bilan et blocages

État au 15/11/2026 · Auteur : Thomas (rôle 1)
Ce document dit ce qui fonctionne, ce qui ne fonctionne pas et pourquoi. Il sert de base au chapitre Identité du rapport de groupe et à la partie « ce qui ne fonctionne pas » de la soutenance.

## 1. En bref

- **Fait :** SRV-DC01 porte toute la configuration d'identité : forêt `ad.nexus360.test`, 5 sites, DNS, 33 OU, groupes AGDLP, 7 comptes d'administration T0/T1/T2, 17 utilisateurs importés, PSO, délégations, LAPS, 9 GPO, DHCP (étendues et réservations), récupération des services.
- **Non fait :** SRV-DC02 n'est pas promu. Il n'y a donc ni réplication, ni basculement DHCP, ni test d'arrêt d'un DC.
- **Jonction :** 2 machines sur 9 sont jointes au domaine (LNX-OPS01 et LNX-WEB01).
- **Chemin réseau :** LNX-GW02 est maintenant dans le tailnet commun et le port 5985 de DC02 répond depuis DC01 (déclaré le 15/11). La promotion peut être retentée.
- **Dépôt :** aucun fichier du rôle Identité n'était versionné avant ce lot.

## 2. État par exigence

| Exigence | Demandé | État | Détail |
|---|---|---|---|
| A1 | Deux DC qui répliquent | **Non fait** | Un seul DC ; DC02 préparé, non promu (§5) |
| A1 | DNS intégré : zones, redirecteurs, enregistrements, alias `intranet` | Fait sur DC01 | Preuves à verser |
| A1 | DHCP en basculement | **Partiel** | Étendues, options et réservations sur DC01 ; basculement impossible sans DC02 |
| A2 | Toutes les machines jointes, dans la bonne OU | **Partiel** | 2 sur 9 (§6) |
| A2 | DC synchronisés sur une source externe | Fait sur DC01 | `fr.pool.ntp.org` |
| A7 | Scripts PowerShell idempotents pilotés par des données | Fait, **non versionné** | Scripts dans `C:\N360\depot` sur DC01 : à pousser dans `windows/identite/` |
| B1 | OU justifiées, 15 utilisateurs ou plus par CSV, AGDLP, matrice | Fait | 17 utilisateurs ; [matrice-droits.md](matrice-droits.md) |
| B3 | Trois niveaux, comptes nominatifs, T0 interdits hors DC | Fait, **non testé** | Le refus de connexion ne se teste que sur une machine Windows jointe |
| B3 | Administrateur intégré hors usage courant | **Partiel** | Il a servi pendant la mise en place et pour DC02 |
| B3 | LAPS sur serveurs et postes, lecture déléguée | Configuré, **non testé** | Aucun serveur ni poste Windows joint |
| B5 | GPO de durcissement documentée | Fait | [gpo-durcissement.md](gpo-durcissement.md) |
| C1 | Services critiques des DC qui redémarrent seuls | Fait sur DC01 | Test de plantage à capturer |
| C4 | Arrêt d'un DC sans coupure | **Non fait** | Dépend de DC02 |
| E1 | DAT, part identité | Fait | [dat-identite.md](dat-identite.md) |
| E2 | Runbook « créer un utilisateur » | Rédigé, **à tester** | [runbook-creer-utilisateur.md](runbook-creer-utilisateur.md) |

Contrôle global du 10/11 : `Test-N360Identity.ps1` donne 47 OK, 12 ECHEC, 8 ALERTE. Presque tous les ECHEC viennent de l'absence de DC02.

## 3. Incidents résolus sur DC01

| Incident | Cause | Résolution |
|---|---|---|
| Domaine créé en `ad.nexus360` au lieu de `ad.nexus360.test` | Nom mal saisi à la promotion, repéré dans les DN | DC rétrogradé, puis promu de nouveau avec le bon nom |
| Simulation (`-WhatIf`) du script LAPS en échec : attribut `ms-LAPS-Password` introuvable | Schéma pas encore étendu au premier passage | Exécution réelle : l'extension du schéma est permanente ; droits LAPS vérifiés ensuite |
| Erreur `NameProtection` au script DHCP | Paramètres DNS du serveur DHCP appliqués dans le mauvais ordre | Trois commandes dans l'ordre (protection désactivée, paramètres, protection réactivée) ; script corrigé |
| Réservations DHCP ignorées | Identifiant client absent du fichier de configuration | Réservations créées avec les adresses MAC, vérifiées |
| Test « comptes nominatifs par niveau » en échec | Joker `?` invalide dans un filtre AD | Filtre réécrit avec trois conditions (`t0-*`, `t1-*`, `t2-*`) |
| Fausse alerte « WhatIf en échec » en boucle | `$LASTEXITCODE` conservé d'une commande précédente | Remise à zéro avant chaque script |
| `dcdiag` signale des erreurs après la promotion | Bruit des tests `SystemLog` et `DFSREvent` | Contrôle avec `dcdiag /skip:systemlog /skip:dfsrevent /q` |
| SRV-DC01 annoncé dans le DNS avec son adresse Tailscale (100.x) et celle de sa carte NAT | Les cartes Tailscale et NAT enregistraient leur adresse dans la zone | Enregistrement DNS désactivé sur ces cartes, enregistrements parasites supprimés, écoute DNS limitée à 10.36.11.10 — **résultat à capturer** |

## 4. Écarts avec les autres rôles

Ces écarts empêchent des fonctions de marcher même une fois le réseau en place. Chacun se corrige en une ligne.

| # | Écart | Rôles | Correction proposée |
|---|---|---|---|
| 1 | `windows/config/shares.json` cite `DL_Compta_RW`, `DL_Compta_R`… L'annuaire contient `DL_FS_Compta_RW`, `DL_FS_Compta_RO`… | 1 et 2 | Reprendre les noms `DL_FS_*` dans `shares.json` |
| 2 | `shares.json` : `"NetBIOSDomain": "AD"`. Le nom NetBIOS réel est `NEXUS360` | 1 et 2 | Corriger la valeur |
| 3 | `ansible/inventory/group_vars/all.yml` cite `GG_Admins_T1` et `GG_Exploitation`. L'annuaire contient `DL_LNX_SSH_Acces`, `DL_LNX_Sudo_Admins`, `DL_LNX_Sudo_Exploitation` | 1 et 3 | Reprendre les noms `DL_LNX_*` |
| 4 | LNX-OPS01 est joint avec `login-policy: allow-realm-logins` : tout compte du domaine peut ouvrir une session sur le bastion | 1 et 3 | `realm deny --all` puis `realm permit -g dl_lnx_ssh_acces`, après un test de connexion |
| 5 | Le rôle Ansible `base` du dépôt ne fait pas la jonction (`realm join`) | 3 | L'ajouter : sinon LNX-WEB01 reconstruit depuis le dépôt (E2) n'est plus dans le domaine |
| 6 | Comptes `svc-backup` et `svc-deploy` attendus par le rôle Exploitation | 1 et 4 | À créer dans `Admin/T1/Services`, avec la PSO des comptes de service |
| 7 | Adresse de LNX-MON01 : 10.36.13.23 (sujet, rôle Linux, politique du tailnet) ou 10.36.14.23 (rôle Exploitation) | tous | Trancher, puis créer l'enregistrement DNS |
| 8 | `monitoring/windows/config/deploiement.json` attend `Set-NexusOU.ps1` et `Import-NexusUsers.ps1`. Les scripts du rôle 1 s'appellent `05-New-OUStructure.ps1` et `12-Import-Users.ps1` | 1 et 4 | Mettre à jour `deploiement.json` quand les scripts seront dans le dépôt |

## 5. SRV-DC02 : état et tentatives

**État.** DC02 est un serveur prêt mais pas un contrôleur de domaine. En place : adresse 10.36.12.11/24, route 10.36.0.0/16 par 10.36.12.1, DNS client 10.36.11.10, nom `SRV-DC02`, rôles AD DS, DNS et DHCP installés. Les services `NTDS` et `Netlogon` sont arrêtés ; `dcdiag` répond « srv-dc02 is not a Directory Server ».

| # | Date | Résultat | Cause |
|---|---|---|---|
| 1 | 09/11 | Le script s'arrête : la résolution de `_ldap._tcp.dc._msdcs` par 10.36.11.10 expire | Aucun routage entre les sites : passerelles absentes |
| 2 | 10/11, 00:54 | « Site AD SITE2 introuvable » | Identifiants du domaine vides dans la session distante ; `SITE2` existe bien |
| 3 | 10/11, 01:04 à 01:46 | Promotion lancée, puis erreur **1722 « The RPC server is unavailable »** vers `SRV-DC01` (dans `dcpromo.log`, 01:46:53) | Non confirmée : hypothèses ci-dessous |
| 4 | 10/11, 02:14 | Lancement local sans identifiants : DC01 les rejette | Compte local de DC02 utilisé au lieu d'un compte du domaine |
| 5 | 10/11, matin | Promotion relancée ; `dcpromo.log` figé depuis 10:49 ; à 11:21, aucun objet `NTDS Settings` sous `SITE2` sur DC01 | Non confirmée : blocage pendant la réplication |
| 6 | 13/11 | Reconfiguration à distance depuis DC01 impossible : port 5985 de DC02 fermé | Cause probable : LNX-GW02 était **partagée** dans le tailnet (« Shared in », constaté le 12/11), pas membre. Un nœud partagé ne donne pas accès aux sous-réseaux qu'il annonce |

**Hypothèses pour les tentatives 3 et 5**, non départagées :

1. La session distante a été coupée pendant la promotion, ce qui arrête le processus.
2. Les ports RPC dynamiques (49152 à 65535) ne passaient pas entre les deux sites.
3. DC02 résolvait `SRV-DC01` vers son adresse Tailscale (100.x) au lieu de 10.36.11.10.
4. Les gros paquets de réplication étaient perdus dans le tunnel (MTU de 1280 octets).

**Ce qui a changé depuis.** LNX-GW02 est maintenant membre du tailnet commun et le port 5985 de DC02 répond depuis DC01 (état déclaré le 15/11, capture à verser). La jonction de LNX-MON01 à travers LNX-GW02, le 10/11, avait déjà montré que LDAP, Kerberos et SMB passent entre le site 2 et DC01.

**Prochaine tentative, dans l'ordre :**

1. Sur DC01 : `Resolve-DnsName srv-dc01.ad.nexus360.test` ne renvoie que 10.36.11.10.
2. Sur DC01 : relever les ports RPC de l'annuaire.
   ```powershell
   Get-NetTCPConnection -State Listen | ? { $_.OwningProcess -eq (Get-Process lsass).Id -and $_.LocalPort -ge 49152 } | Select -Unique LocalPort
   ```
3. Sur DC02 : tester ces ports et la taille des paquets.
   ```powershell
   Test-NetConnection 10.36.11.10 -Port 135
   Test-NetConnection 10.36.11.10 -Port <port relevé>
   ping -f -l 1200 10.36.11.10
   ```
4. Lancer la promotion **sur la console de DC02** (pas dans une session distante), avec un compte du domaine, et ne rien fermer avant le redémarrage.
5. Vérifier sur DC01 : `Get-ADDomainController -Filter * | Select Name, Site, IPv4Address`, puis `repadmin /replsummary`.

Garder les sorties des étapes 1 à 3, même en cas d'échec : elles départagent les hypothèses.

## 6. Jonction des machines (A2)

| Machine | OU cible | État | Preuve |
|---|---|---|---|
| LNX-OPS01 | Serveurs/Linux | **Jointe** | `realm list` : `configured: kerberos-member` (vu le 12 ou 13/11) — à verser |
| LNX-WEB01 | Serveurs/Linux | **Jointe** (déclaré le 15/11) | À verser : `realm list` et `Get-ADComputer LNX-WEB01` |
| LNX-MON01 | Serveurs/Linux | À confirmer | `realm list` positif le 10/11 ; non comptée parmi les machines jointes le 15/11 |
| LNX-APP01 | Serveurs/Linux | Non jointe | |
| SRV-FS01, SRV-MGT01 | Serveurs/Windows | Non jointes | Chemin réseau entre le PC d'Aziz et DC01 à établir |
| CLI-W11-01, CLI-W11-02 | Postes/Windows, Postes/Pilote | Non joints | D'après `reseau/docs/dat-reseau.md`, les postes tournent dans le labo local du rôle Réseau |
| CLI-LNX01 | Postes/Linux | Non joint | Idem |

Compte utilisé : `svc-adjoin`, mot de passe saisi à la main. Ce que la jonction des deux Linux prouve : DNS, Kerberos et LDAP fonctionnent entre le site 3 et DC01 à travers LNX-GW03 et LNX-GW01.

## 7. Dépendances

| Bloqué | Dépend de | Qui |
|---|---|---|
| Promotion de DC02, réplication | Chemin stable DC02 ↔ DC01 (acquis le 15/11), une tentative faite à la console de DC02 | Thomas, Dilane |
| Basculement DHCP, ordre DNS des DC, C4 | DC02 promu | Thomas |
| Jonction de SRV-FS01 et SRV-MGT01, LAPS, GPO serveurs, WSUS, WEF | Passerelle et site du PC d'Aziz dans le tailnet commun | Aziz, Benor |
| Jonction des postes, tests des partages, démonstration du tiering | Postes reliés au tailnet commun ; SRV-FS01 joint | Benor, Aziz |
| Droits `sudo` et SSH par groupe AD | Noms de groupes alignés (§4, écart 3) | Ugo, Thomas |

## 8. Reste à faire, par priorité

1. **Pousser le travail dans le dépôt** : scripts et configuration (`windows/identite/`), ces documents, les preuves. Avec le compte de Thomas, par branche et pull request.
2. **Capturer les preuves de DC01** : voir [preuves/README.md](preuves/README.md).
3. **Promouvoir DC02** (§5), puis vérifier la réplication.
4. **Après DC02** : DNS client croisé des DC, basculement DHCP à l'état `Normal`, récupération des services sur DC02, test d'arrêt d'un DC.
5. **Aligner les noms de groupes** avec Aziz et Ugo (§4).
6. **Joindre** LNX-APP01, puis SRV-FS01, SRV-MGT01 et les postes dès que leur chemin réseau existe.
7. **Tester** le tiering et LAPS sur une machine Windows jointe.
8. **Nettoyer** : supprimer le fichier de mots de passe initiaux de DC01, réinitialiser les comptes T0 et `svc-adjoin`, vider `TrustedHosts`, ne plus utiliser `Administrateur`.

## 9. Pour la soutenance

| Démontrable aujourd'hui | Pas démontrable, et pourquoi |
|---|---|
| Annuaire, OU, groupes AGDLP, comptes par niveau, PSO, GPO sur DC01 | Réplication entre deux DC : DC02 n'est pas promu |
| Import d'un utilisateur par CSV, relance à 0 changement | Basculement DHCP et arrêt d'un DC : exigent DC02 |
| Connexion d'un compte du domaine sur LNX-OPS01 (SSSD) | Refus d'un compte T0 sur un poste : aucun poste joint |
| Redémarrage automatique du service DNS après un plantage | LAPS : aucun serveur ni poste Windows joint |

Questions probables :

- *Pourquoi la promotion de DC02 a-t-elle échoué ?* Six essais documentés : routage absent, identifiants vides, erreur RPC 1722, compte local, blocage en réplication, passerelle partagée au lieu d'être membre du tailnet.
- *Pourquoi ne pas faire passer l'annuaire par les adresses Tailscale ?* L'annuaire associe les adresses 10.36.x à un site. Les adresses 100.x n'appartiennent à aucun site et polluent le DNS.
- *Pourquoi AGDLP ?* Les droits sont portés par des groupes de ressource. Une arrivée ou un départ ne touche jamais une ACL.
- *Pourquoi trois niveaux ?* Un poste compromis ne doit jamais livrer un compte capable d'administrer les serveurs ou l'annuaire.
