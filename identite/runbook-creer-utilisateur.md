# Runbook : créer un utilisateur (E2)

| | |
|---|---|
| **Objectif** | Créer le compte d'un nouveau collaborateur, avec les bons accès, sans toucher aux ACL des serveurs |
| **Qui** | Un compte T1 (`t1-*`, membre de `DL_T1_AD_GestionComptes`). Pas le compte `Administrateur` |
| **Où** | SRV-DC01 aujourd'hui ; SRV-MGT01 (outils RSAT) quand il sera joint au domaine |
| **Durée** | 5 minutes |
| **Dernier test** | AAAA-MM-JJ par … (résultat : …) — à remplir après chaque test |

## Principe

Les droits viennent du groupe de service (`GG_<Service>`), jamais du compte : voir [matrice-droits.md](matrice-droits.md). Créer un utilisateur revient donc à le placer dans la bonne OU et dans le bon `GG_`.

## Méthode 1 : par le fichier CSV (méthode normale)

C'est la méthode exigée par B1 : les comptes sont créés par script depuis un fichier de données, et le changement est tracé dans Git.

1. Créer une branche : `git switch -c identite/ajout-<login>`.
2. Ajouter **une ligne** dans `windows/identite/config/users.csv`, sur le modèle des lignes existantes (mêmes colonnes : identité, service, groupe).
3. Simuler :
   ```powershell
   cd C:\N360\depot\windows\scripts      # copie du dépôt sur SRV-DC01 ; dans Git : windows/identite/scripts
   .\12-Import-Users.ps1 -WhatIf
   ```
   Attendu : une seule ligne « Créer l'utilisateur », pour le nouveau compte.
4. Appliquer : `.\12-Import-Users.ps1`.
5. Relancer la même commande. Attendu : `0 changement(s)`. C'est la preuve d'idempotence.
6. Récupérer le mot de passe initial dans le dossier `N360-secrets` du profil de l'administrateur (hors dépôt). Le remettre à la personne **de vive voix ou par un canal privé**, puis supprimer la ligne du fichier.
7. Pousser la branche, ouvrir une pull request, la faire relire.
8. Ajouter une ligne au journal : [journal.md](journal.md).

## Méthode 2 : par la console (dépannage)

À utiliser si le dépôt n'est pas accessible. Reporter ensuite la ligne dans `users.csv`, sinon le fichier ne décrit plus l'annuaire.

1. Ouvrir **Utilisateurs et ordinateurs Active Directory** (`dsa.msc`).
2. Aller dans `NEXUS360 > Utilisateurs > <Service>`. Clic droit, **Nouveau > Utilisateur**.
3. Nom d'ouverture de session : première lettre du prénom + nom, en minuscules, sans accent (exemple : `croux`).
4. Saisir un mot de passe initial de 12 caractères ou plus. Laisser cochée la case **L'utilisateur doit changer le mot de passe à la prochaine ouverture de session**.
5. Onglet **Membre de** : ajouter `GG_<Service>`. Ne rien ajouter d'autre : `GG_Personnel` est hérité, les `DL_` ne reçoivent jamais de compte.

## Vérification

```powershell
Get-ADUser <login> -Properties MemberOf, pwdLastSet | Select Name, Enabled, DistinguishedName, pwdLastSet
Get-ADPrincipalGroupMembership <login> | Select Name
```

Attendu :

- le compte est dans `OU=<Service>,OU=Utilisateurs,OU=NEXUS360,DC=ad,DC=nexus360,DC=test` ;
- `pwdLastSet` vaut 0 (changement exigé) ;
- les groupes sont `Utilisateurs du domaine` et `GG_<Service>`.

Test fonctionnel (quand un poste sera joint) : la personne ouvre une session sur CLI-W11-01, change son mot de passe, et voit le partage `Commun` plus celui de son service.

## Cas particuliers

| Cas | Action |
|---|---|
| La personne a besoin d'un accès en lecture au partage d'un autre service | Ajouter son `GG_` au `DL_FS_<Partage>_RO`, jamais le compte lui-même |
| La personne administre des serveurs ou des postes | Créer en plus un compte `t1-<login>` ou `t2-<login>` dans OU=Admin : opération T0, voir [modele-administration.md](modele-administration.md) |
| Compte créé au mauvais endroit | Il apparaît dans `Utilisateurs/Nouveaux` : le déplacer dans l'OU de son service |
| Départ d'un collaborateur | Désactiver le compte, retirer ses groupes, le déplacer dans `OU=Desactives` ; suppression après le délai convenu |
| Mot de passe oublié | Réinitialisation par un compte T2 (`DL_T2_Support_ResetMdp`), avec changement exigé à la connexion |

## Retour arrière

- Méthode 1 : `git revert` de la ligne ajoutée, puis désactiver le compte et le déplacer dans `OU=Desactives`. Vérifier en `-WhatIf` ce que le script fait d'une ligne retirée avant de compter sur lui pour supprimer.
- Méthode 2 : désactiver le compte. Ne le supprimer qu'après vérification : un compte supprimé perd son identifiant (SID) et ses droits.
