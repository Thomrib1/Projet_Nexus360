# GPO de durcissement Windows (B5) et de tiering (B3)

État au 15/11/2026. Les 9 GPO sont créées et liées sur SRV-DC01. Leur effet sur les serveurs membres et les postes n'est pas vérifié : aucune machine Windows n'est encore jointe.

Source des réglages : `windows/identite/config/gpo.json`. Rapport HTML de chaque GPO : `docs/identite/exports/gpo/` (à verser, voir [preuves/README.md](preuves/README.md)). Le rapport HTML fait foi sur le détail des réglages.

## 1. Vue d'ensemble

| GPO | Liée à (ordre) | Rôle |
|---|---|---|
| `N360-Domaine-Comptes` | racine du domaine (1) | Mot de passe et verrouillage des comptes du domaine |
| `N360-Base-Durcissement` | racine du domaine (2) | Socle commun à toutes les machines Windows, DC compris |
| `N360-DC-Durcissement` | OU=Domain Controllers (1) | Réglages propres aux contrôleurs de domaine |
| `N360-DC-Droits` | OU=Domain Controllers (2) | T1 et T2 interdits sur les DC |
| `N360-Serveurs-Droits` | OU=Serveurs (1) | T0 et T2 interdits ; administration locale par T1 |
| `N360-LAPS-Serveurs` | OU=Serveurs (2) | LAPS, 20 caractères, lecture par `DL_T1_LAPS_Lecture` |
| `N360-Postes-Droits` | OU=Postes (1) | T0 et T1 interdits ; administration locale par T2 |
| `N360-LAPS-Postes` | OU=Postes (2) | LAPS, 16 caractères, lecture par `DL_T2_LAPS_Lecture` |
| `N360-Quarantaine-Droits` | OU=Quarantaine (1) | T0 interdits |

Toutes les GPO ont la partie « utilisateur » désactivée : elles ne contiennent que des réglages « ordinateur », ce qui accélère leur application.
La *Default Domain Policy* reste liée en dernier à la racine. Elle n'est pas modifiée : en cas d'erreur, on délie une GPO `N360-*` sans toucher aux stratégies par défaut.

## 2. `N360-Domaine-Comptes`

| Réglage | Valeur | Pourquoi |
|---|---|---|
| Longueur minimale | 12 caractères | Longueur courante recommandée pour un compte standard |
| Complexité | activée | |
| Historique | 24 mots de passe | Empêche de réutiliser un ancien mot de passe |
| Durée maximale | 365 jours | Un changement fréquent pousse à des mots de passe faibles |
| Verrouillage | 10 essais, 15 minutes | Bloque la recherche par force brute sans gêner l'utilisateur distrait |

Les comptes à privilèges et les comptes de service ont des règles plus strictes par PSO : voir le DAT §2.7.
Une seule GPO peut porter la politique de mot de passe du domaine : elle doit être liée à la racine.

## 3. `N360-Base-Durcissement`

| Réglage | Menace visée |
|---|---|
| Signature SMB exigée | Relais et altération des échanges SMB |
| NTLMv2 seul, LM et NTLMv1 refusés | Cassage hors ligne des anciens protocoles |
| Accès anonymes restreints | Énumération des comptes et des partages sans authentification |
| Audit avancé (connexions, gestion des comptes, changements de stratégie) | Sans audit, pas d'investigation possible (D2) ni de collecte (D1) |
| Taille des journaux augmentée (Sécurité 256 Mo, autres 64 Mo) | Les événements ne sont pas écrasés avant leur collecte |
| LLMNR désactivé | Usurpation de nom sur le réseau local |
| WDigest désactivé | Mots de passe en clair dans la mémoire de LSASS |
| Protection de LSA | Extraction d'identifiants de la mémoire |
| Pare-feu Windows actif sur les trois profils | Réduction de la surface exposée |

## 4. `N360-DC-Durcissement`

| Réglage | Pourquoi |
|---|---|
| Signature LDAP exigée | Empêche le relais vers LDAP |
| Liaison de canal LDAP | Lie la session LDAPS au canal TLS |
| Journal Sécurité de 1 Go | Un DC produit beaucoup plus d'événements qu'un membre |

Risque connu : la signature LDAP exigée refuse les clients qui font une liaison simple en clair. SSSD utilise Kerberos (GSSAPI) : les Linux joints ne sont pas concernés. LNX-OPS01 et LNX-WEB01 se sont joints après la création de cette GPO.

## 5. GPO de droits (tiering)

Principe et tableau des niveaux : [modele-administration.md](modele-administration.md) §4.
Point d'attention : les droits utilisateur de plusieurs GPO **ne se fusionnent pas**. Pour un même droit, la GPO qui gagne remplace la liste entière. C'est pourquoi chaque OU a une seule GPO de droits.

## 6. Contrôles

| Commande (sur SRV-DC01) | Attendu |
|---|---|
| `Get-GPO -All \| ? DisplayName -like 'N360-*' \| ft DisplayName, GpoStatus` | 9 GPO, `UserSettingsDisabled` |
| `(Get-GPInheritance -Target 'DC=ad,DC=nexus360,DC=test').GpoLinks \| ft DisplayName, Order` | `N360-Domaine-Comptes` (1), `N360-Base-Durcissement` (2), `Default Domain Policy` (3) |
| `Get-ADDefaultDomainPasswordPolicy` | `MinPasswordLength 12`, `LockoutThreshold 10` |
| `gpresult /scope computer /r` sur SRV-DC01 | `N360-Base-Durcissement`, `N360-DC-Durcissement`, `N360-DC-Droits` appliquées |
| `gpresult /scope computer /r` sur SRV-FS01 | `N360-Base-Durcissement`, `N360-Serveurs-Droits`, `N360-LAPS-Serveurs` — **bloqué**, serveur non joint |

## 7. Retour arrière

1. Délier la GPO fautive dans la console de gestion des stratégies de groupe (le lien, pas la GPO).
2. `gpupdate /force` sur la machine touchée.
3. Corriger `gpo.json`, relancer le script en `-WhatIf`, puis en réel.
4. Consigner au journal.

Les GPO `N360-*` ne contiennent aucun mot de passe : leurs exports sont versionnables.
