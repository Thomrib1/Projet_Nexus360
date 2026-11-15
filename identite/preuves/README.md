# Preuves du rôle Identité

Deux formes de preuve, toutes deux dans le dépôt :

- **`docs/identite/exports/`** : sorties texte et rapports HTML. Un lecteur ou un outil les lit sans erreur.
- **`docs/identite/preuves/`** : captures d'écran, nommées `<exigence>-<sujet>.png`. Elles servent de secours en soutenance.

Règles :

- La date et le nom de la machine doivent être visibles. Les exports les écrivent en tête de fichier. Pour une capture, taper `hostname; Get-Date` avant la commande.
- **Aucun mot de passe.** Ne jamais verser le fichier des mots de passe initiaux ni une capture qui le montre. Pour LAPS, montrer la date d'expiration, pas le mot de passe.
- Un échec est une preuve : garder les sorties des essais ratés de DC02.
- Cocher une ligne quand le fichier est dans le dépôt.

## 1. Exports automatiques (SRV-DC01)

Une seule commande, en lecture seule : `windows/identite/scripts/Export-N360Preuves.ps1`. Elle produit les fichiers suivants.

| ☐ | Fichier | Exigence | Contenu | Commande principale |
|---|---|---|---|---|
| ☐ | `A1-domaine.txt` | A1 | Domaine, forêt, rôles FSMO | `Get-ADDomain`, `Get-ADForest` |
| ☐ | `A1-dc.txt` | A1 | Contrôleurs de domaine présents | `Get-ADDomainController -Filter *` |
| ☐ | `A1-sites.txt` | A1 | Sites, sous-réseaux, liens | `Get-ADReplicationSite`, `Get-ADReplicationSubnet` |
| ☐ | `A1-replication.txt` | A1 | État de la réplication | `repadmin /replsummary` |
| ☐ | `A1-dcdiag.txt` | A1 | Santé du DC | `dcdiag /skip:systemlog /skip:dfsrevent` |
| ☐ | `A1-dns-zones.txt` | A1 | Zones, redirecteurs, interfaces d'écoute | `Get-DnsServerZone`, `Get-DnsServerForwarder` |
| ☐ | `A1-dns-enregistrements.txt` | A1 | A, PTR, alias `intranet` | `Get-DnsServerResourceRecord` |
| ☐ | `A1-dns-dc01.txt` | A1 | DC01 résolu en 10.36.11.10 seulement | `Resolve-DnsName`, `Get-DnsClient` |
| ☐ | `A1-heure.txt` | A1, A2 | Source de temps du PDC | `w32tm /query /source` |
| ☐ | `A1-dhcp.txt` | A1 | Étendues, options, réservations, basculement | `Get-DhcpServerv4Scope`, `Get-DhcpServerv4Failover` |
| ☐ | `A2-ordinateurs.txt` | A2 | Comptes ordinateur et leur OU | `Get-ADComputer -Filter *` |
| ☐ | `B1-ou.txt` | B1 | Arborescence d'OU | `Get-ADOrganizationalUnit -Filter *` |
| ☐ | `B1-groupes.txt` | B1 | Groupes, étendue, membres | `Get-ADGroup`, `Get-ADGroupMember` |
| ☐ | `B1-utilisateurs.txt` | B1 | Les 17 utilisateurs et leur service | `Get-ADUser -Filter *` |
| ☐ | `B3-comptes-admin.txt` | B3 | Comptes par niveau, Admins du domaine, Protected Users, dernière utilisation d'`Administrateur` | `Get-ADUser`, `Get-ADGroupMember` |
| ☐ | `B3-pso.txt` | B3 | PSO, cibles, stratégie résultante | `Get-ADFineGrainedPasswordPolicy` |
| ☐ | `B3-delegations.txt` | B3 | Droits délégués sur les OU | `dsacls` |
| ☐ | `B3-laps.txt` | B3 | Schéma étendu, droits de lecture LAPS | `Find-LapsADExtendedRights` |
| ☐ | `B5-gpo.txt` | B5 | Liste des GPO et de leurs liens | `Get-GPO -All`, `Get-GPInheritance` |
| ☐ | `gpo/N360-*.html` | B5, B3 | Rapport complet de chaque GPO | `Get-GPOReport -ReportType Html` |
| ☐ | `C1-services.txt` | C1 | Actions de récupération des services | `sc.exe qfailure DNS` |

Pour afficher une preuve à l'écran sans le script, par exemple la liste des OU :

```powershell
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=NEXUS360,DC=ad,DC=nexus360,DC=test" |
  Sort-Object DistinguishedName | Format-Table Name, DistinguishedName -AutoSize
```

## 2. Preuves à produire à la main

Ces preuves demandent une action ou une autre machine. Enregistrer la sortie en `.txt` dans `preuves/`, et faire une capture.

| ☐ | Fichier | Exigence | Quoi | Comment |
|---|---|---|---|---|
| ☐ | `B1-import-idempotent.txt` | B1, A7 | Import relancé : 0 changement | `.\12-Import-Users.ps1 -WhatIf`, puis réel, puis relance |
| ☐ | `C1-dns-redemarrage.txt` | C1 | Le service DNS repart seul | `Stop-Process -Name dns -Force` ; attendre 40 s ; `Get-Service DNS` ; `Get-WinEvent -LogName System -MaxEvents 5 \| ? Id -in 7031,7034` |
| ☐ | `A1-test-identite.txt` | toutes | Résultat de `Test-N360Identity.ps1` | Relancer le script et garder la sortie complète |
| ☐ | `A2-lnx-ops01-realm.txt` | A2 | LNX-OPS01 joint | Sur OPS01 : `hostname; date; realm list; id t1-lmartin@ad.nexus360.test` |
| ☐ | `A2-lnx-web01-realm.txt` | A2 | LNX-WEB01 joint | Idem, par le bastion |
| ☐ | `A2-lnx-mon01-realm.txt` | A2 | LNX-MON01 : joint ou non | Idem ; lever le doute |
| ☐ | `A2-chrony-linux.txt` | A2 | Linux synchronisés sur les DC | Sur OPS01 : `chronyc sources` |
| ☐ | `A8-dc01-vers-dc02.txt` | A1, A8 | Chemin DC01 → DC02 | Sur DC01 : `Test-NetConnection 10.36.12.11 -Port 5985` |
| ☐ | `B3-reset-mdp-t2.txt` | B3 | Délégation du support | En `t2-hdubois` : réinitialiser `croux` (succès), puis un compte de OU=Admin (refus) |
| ☐ | `E2-runbook-test.txt` | E2 | Runbook « créer un utilisateur » testé | Créer un compte de test en suivant le runbook ; garder la vérification |

## 3. Preuves des échecs de DC02

| ☐ | Fichier | Quoi | Comment |
|---|---|---|---|
| ☐ | `A1-dc02-etat.txt` | DC02 n'est pas un DC | Sur DC02 : `hostname; Get-Date; Get-Service NTDS, DNS, Netlogon; dcdiag /q` |
| ☐ | `A1-dc02-dcpromo-1722.txt` | Erreur RPC 1722 du 10/11 | Sur DC02 : `Get-Content C:\Windows\debug\dcpromo.log -Tail 60` |
| ☐ | `A1-dc02-ports.txt` | Ports AD et RPC depuis DC02 | Sur DC02 : `53,88,135,389,445,464,3268,9389 \| % { Test-NetConnection 10.36.11.10 -Port $_ \| Select RemotePort, TcpTestSucceeded }` |
| ☐ | `A1-dc02-mtu.txt` | Taille des paquets dans le tunnel | Sur DC02 : `ping -f -l 1000 10.36.11.10`, puis `-l 1200`, puis `-l 1400` |
| ☐ | `A1-dc01-sans-dc02.txt` | DC01 ne liste qu'un DC | Sur DC01 : `Get-ADDomainController -Filter * \| Select Name, Site, IPv4Address` |

## 4. Preuves bloquées

Elles ne peuvent pas exister aujourd'hui. Le rapport doit le dire, pas les simuler.

| Preuve | Exigence | Bloquée par |
|---|---|---|
| `repadmin /replsummary` avec deux DC, 0 échec | A1 | SRV-DC02 non promu |
| `Get-DhcpServerv4Failover` à l'état `Normal` | A1 | SRV-DC02 non promu |
| Arrêt d'un DC sans coupure d'authentification, de DNS ni de DHCP | C4 | SRV-DC02 non promu |
| Connexion d'un compte `t0-*` refusée sur un poste (événement 4625, sous-statut `0xC000015B`) | B3 | Aucun poste joint |
| `Get-LapsADPassword` lu en T1, refusé en T2 | B3 | Aucun serveur ni poste Windows joint |
| `gpresult /r` sur un serveur membre et sur un poste | B5 | Idem |

## 5. À ne jamais verser

- Le fichier `secrets-*.csv` des mots de passe initiaux, ni la capture du 10/11 qui l'affiche.
- Une clé Tailscale (`tskey-…`), même expirée.
- Une capture où un mot de passe est tapé en clair dans une commande.
