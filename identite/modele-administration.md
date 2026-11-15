# Modèle d'administration en trois niveaux (B3)

État au 15/11/2026. Mis en place sur SRV-DC01. Les tests qui demandent un serveur ou un poste Windows joint ne sont pas faits : voir §6.

## 1. Principe

Un compte d'un niveau ne se connecte jamais sur une machine d'un niveau inférieur. Un poste compromis ne livre donc jamais un compte capable d'administrer les serveurs ou l'annuaire.

| Niveau | Administre | Se connecte sur | Interdit sur |
|---|---|---|---|
| **T0** | Annuaire, DC, GPO, schéma | SRV-DC01, SRV-DC02 | serveurs membres, postes |
| **T1** | Serveurs membres Windows et Linux | SRV-FS01, SRV-MGT01, serveurs Linux | DC, postes |
| **T2** | Postes de travail, support utilisateurs | CLI-W11-01, CLI-W11-02, CLI-LNX01 | DC, serveurs |

## 2. Comptes nominatifs

Une personne qui administre plusieurs niveaux a un compte par niveau, plus son compte de bureautique. Les noms sont fictifs (voir R-ID-03 du DAT).

| Compte | Niveau | OU | Groupe de rôle |
|---|---|---|---|
| `t0-lmartin` | T0 | Admin/T0/Comptes | `GG_T0_Admins` |
| `t0-ebernard` | T0 | Admin/T0/Comptes | `GG_T0_Admins` |
| `t1-lmartin` | T1 | Admin/T1/Comptes | `GG_T1_Admins`, `GG_LNX_Admins` |
| `t1-ebernard` | T1 | Admin/T1/Comptes | `GG_T1_Admins`, `GG_LNX_Admins` |
| `t1-hdubois` | T1 | Admin/T1/Comptes | `GG_LNX_Exploitation` |
| `t2-hdubois` | T2 | Admin/T2/Comptes | `GG_T2_Admins` |
| `t2-ebernard` | T2 | Admin/T2/Comptes | `GG_T2_Admins` |

Créés le 09/11/2026. Mots de passe de 16 caractères générés à l'exécution, jamais écrits dans le dépôt.

Protections posées sur ces comptes :

- **Protected Users** pour les `t0-*` et `t1-*` : pas de NTLM, pas de délégation, tickets Kerberos courts.
- **« Le compte est sensible et ne peut pas être délégué »** sur les 7 comptes.
- **PSO `PSO-Comptes-Privilegies`** : 16 caractères, verrouillage après 5 essais.

## 3. Le compte Administrateur intégré

Le sujet demande qu'il ne serve plus au quotidien.

- Usage cible : compte de secours uniquement, mot de passe long gardé sous enveloppe, toute utilisation consignée au journal.
- État réel : il a servi pendant la mise en place et pour les tentatives de promotion de DC02. À consigner dans [journal.md](journal.md).
- `GG_T0_Admins` est membre de « Admins du domaine » : les `t0-*` remplacent l'Administrateur intégré pour le travail courant.

## 4. Ce qui fait respecter les niveaux

| Mécanisme | Où | Effet |
|---|---|---|
| GPO `N360-DC-Droits` | OU=Domain Controllers | T1 et T2 interdits de connexion sur les DC |
| GPO `N360-Serveurs-Droits` | OU=Serveurs | T0 et T2 interdits ; `DL_T1_Srv_AdminLocal` administrateur local |
| GPO `N360-Postes-Droits` | OU=Postes | T0 et T1 interdits ; `DL_T2_Postes_AdminLocal` administrateur local |
| GPO `N360-Quarantaine-Droits` | OU=Quarantaine | T0 interdits sur une machine pas encore rangée |
| OU=Admin | — | Gérée par T0 seul : un T1 ne peut pas modifier un compte ou un groupe à privilèges |

Le détail des droits de refus de connexion posés par chaque GPO est dans son rapport HTML (`docs/identite/exports/gpo/`).

## 5. Délégations

| Groupe | Sur | Droit délégué |
|---|---|---|
| `DL_T1_AD_GestionComptes` | OU=Utilisateurs, OU=Groupes | Créer, modifier, supprimer les utilisateurs et les groupes métier |
| `DL_T2_Support_ResetMdp` | OU=Utilisateurs | Réinitialiser un mot de passe, déverrouiller un compte |
| `DL_T1_Jonction` | OU=Serveurs | Créer et joindre des comptes ordinateur |
| `DL_T2_Jonction` | OU=Postes | Créer et joindre des comptes ordinateur |
| `DL_T1_LAPS_Lecture` | OU=Serveurs | Lire le mot de passe LAPS des serveurs |
| `DL_T2_LAPS_Lecture` | OU=Postes | Lire le mot de passe LAPS des postes |

Aucune délégation ne porte sur OU=Admin. Un compte du support (T2) peut donc réinitialiser le mot de passe d'un utilisateur, mais pas celui d'un administrateur.

`svc-adjoin` est membre direct de `DL_T1_Jonction` et `DL_T2_Jonction`. C'est une exception assumée à AGDLP : c'est un compte de service, pas une personne. Preuve observée sur LNX-OPS01 (12 ou 13/11) : `id svc-adjoin@ad.nexus360.test` renvoie ces deux groupes.

## 6. LAPS

- **Windows LAPS natif** (intégré à Windows Server 2025 et Windows 11). L'ancien LAPS par MSI est écarté : il est en fin de vie et stocke le mot de passe en clair dans l'annuaire.
- Schéma étendu sur SRV-DC01 (opération permanente ; elle demande une appartenance à « Administrateurs du schéma », à retirer ensuite et à consigner au journal).
- Le mot de passe est **chiffré** dans l'annuaire, déchiffrable par le seul groupe de lecture du niveau.

| GPO | OU | Longueur | Lecture |
|---|---|---|---|
| `N360-LAPS-Serveurs` | Serveurs | 20 caractères | `DL_T1_LAPS_Lecture` |
| `N360-LAPS-Postes` | Postes | 16 caractères | `DL_T2_LAPS_Lecture` |

Les DC n'ont pas de compte local : LAPS ne les concerne pas (hors mot de passe DSRM, non géré ici).

## 7. Tests

| Test | Attendu | État |
|---|---|---|
| `Get-ADGroupMember "Protected Users"` | les `t0-*` et `t1-*` | À capturer |
| `Get-ADUserResultantPasswordPolicy t1-hdubois` | `PSO-Comptes-Privilegies` | À capturer |
| `Get-ADUserResultantPasswordPolicy svc-adjoin` | `PSO-Comptes-Service` | À capturer |
| `Find-LapsADExtendedRights -Identity "OU=Postes,OU=NEXUS360,DC=ad,DC=nexus360,DC=test"` | `DL_T2_LAPS_Lecture` | À capturer |
| `t2-hdubois` réinitialise le mot de passe de `croux` | succès | À faire |
| `t2-hdubois` réinitialise un compte de OU=Admin | accès refusé | À faire |
| `t0-lmartin` ouvre une session sur un poste | refusé, événement 4625 sous-statut `0xC000015B` | **Bloqué** : aucun poste joint |
| `Get-LapsADPassword SRV-FS01` en T1, puis en T2 | mot de passe, puis accès refusé | **Bloqué** : SRV-FS01 non joint |

Ne jamais capturer la sortie de `Get-LapsADPassword` avec le mot de passe visible : montrer la date d'expiration (`-AsPlainText` absent).
