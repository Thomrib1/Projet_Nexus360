## Quoi et pourquoi

<!-- Une ou deux phrases : ce que change cette PR et pourquoi. Lier l'issue : "Closes #12" -->

**Rôle concerné** : <!-- 1 Identité · 2 Services Windows · 3 Linux · 4 Exploitation · 5 Réseau et postes -->
**Exigence(s)** : <!-- ex. C2, D1, A6 -->
**Machines touchées** : <!-- ex. LNX-MON01 (PC rôle 4), SRV-FS01 (PC rôle 2) -->

## Dépendances

- [ ] Aucune
- [ ] Dépend d'un autre rôle : <!-- ex. "rôle 3 : /srv/backup doit être monté (PR #8)" -->
- [ ] Un autre rôle doit agir après la fusion : <!-- ex. "rôle 2 : relancer Install-WindowsExporter.ps1 sur FS01" -->

## Comment ça a été vérifié

- [ ] Le pipeline est vert (analyse + vérification à blanc)
- [ ] J'ai lu le `--check --diff` / le `-WhatIf` du pipeline : seuls les changements attendus apparaissent
- [ ] Testé sur la machine (commande + résultat ci-dessous)

```
<!-- commande et sortie -->
```

## Risque et retour arrière

**Risque** : <!-- faible / moyen / élevé + pourquoi -->
**Retour arrière** : `git revert <commit>` puis PR <!-- ou procédure spécifique -->

## Traçabilité

- [ ] Ligne ajoutée au journal d'exploitation (`docs/exploitation/journal-exploitation.md`)
- [ ] `CHANGELOG.md` mis à jour (si changement visible)
- [ ] DAT mis à jour (adresses, ports, comptes, versions) si besoin
- [ ] Aucun secret dans la PR (le pipeline lance gitleaks)
