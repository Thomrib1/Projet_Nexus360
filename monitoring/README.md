# Nexus360 — Socle serveurs Linux/Windows du siège (mission T01)

Infrastructure du site de Paris décrite **entièrement en code** : si un serveur tombe, on le reconstruit depuis ce dépôt.

| Dossier | Contenu | Rôle propriétaire |
|---|---|---|
| `ansible/` | Configuration de tous les Linux (`site.yml`, rôles `base`, `web`, `ops`, `mon`) | 3 (Linux), 4 (`mon`) |
| `windows/` | Scripts PowerShell idempotents (`-WhatIf`) pilotés par `config/*.json|*.csv` | 1, 2 |
| `reseau/` | Politique du tailnet, reconstruction des passerelles | 5 |
| `.github/workflows/` | Pipeline CI/CD | 4 |
| `scripts/` | Bilan d'infrastructure, tests d'alertes, test de restauration | 4 |
| `tests/` | Tests unitaires des règles d'alerte | 4 |
| `docs/` | DAT, runbooks, PV, fiches d'incident, journal d'exploitation, preuves | tous |

## Organisation

- Qui héberge quelle VM, sur quel PC, et qui dépend de qui : [`docs/organisation/ORGANISATION-EQUIPE.md`](docs/organisation/ORGANISATION-EQUIPE.md)
- Règles du dépôt (création, branches, PR, CODEOWNERS) : [`docs/organisation/GITHUB-DEPOT.md`](docs/organisation/GITHUB-DEPOT.md)
- Une branche courte par tâche, `r<N>/<type>-<sujet>` (N = numéro du rôle), fusionnée par PR relue : pas de branche permanente par personne.

## Déployer

Tout déploiement passe par le pipeline : **branche → pull request relue → fusion dans `main`**.

| Étape | Ce qui se passe |
|---|---|
| Pull request | analyse statique (yamllint, ansible-lint, promtool, gitleaks, PSScriptAnalyzer) puis `ansible-playbook --check --diff` et PowerShell `-WhatIf` |
| Fusion dans `main` | déploiement Linux, **second passage qui doit afficher `changed=0`**, déploiement Windows depuis SRV-MGT01, tests de fumée |

Déploiement manuel de secours, depuis LNX-OPS01 :

```bash
cd ~/nexus360/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook site.yml --check --diff          # voir ce qui changerait
ansible-playbook site.yml -e deploy_commit=$(git rev-parse HEAD)
ansible-playbook site.yml --limit lnx-mon01 --tags ...   # une seule machine
```

## Lancer la CI

- Automatique à chaque PR et à chaque fusion dans `main`.
- Manuel : onglet **Actions → pipeline → Run workflow** (ex. après reconstruction d'une VM).
- Runner auto-hébergé : service `actions.runner.*` sur LNX-OPS01 (label `nexus360`).
- Secrets requis (Settings → Secrets → Actions) : `ANSIBLE_VAULT_PASSWORD`, `GRAFANA_TOKEN` (optionnel).

## Reconstruire un serveur

1. Réinstaller Rocky Linux 10 avec la même IP et le même nom (voir DAT).
2. Déposer la clé du runner pour le compte `ansible`.
3. Relancer le pipeline (**Run workflow**) ou `ansible-playbook site.yml --limit <machine>`.

## Superviser

- Grafana : `http://lnx-mon01.ad.nexus360.test:3000` (depuis SRV-MGT01 ou par tunnel SSH via le bastion)
- Prometheus : `http://lnx-mon01.ad.nexus360.test:9090` — Alertmanager : `http://lnx-mon01.ad.nexus360.test:9093`
- Bilan complet : `bash scripts/check-infra.sh`

## Règles

- Aucun secret en clair : Ansible Vault + secrets GitHub ; gitleaks bloque les PR fautives.
- Chacun committe avec son propre compte ; messages `type(périmètre): description`.
- Retour arrière : `git revert <commit>` + PR → le pipeline redéploie l'état précédent.
- Livraison : étiquette `v1.0` avant le gel.
