#!/usr/bin/env bash
# =============================================================================
# init-depot.sh — Création et configuration du dépôt GitHub Nexus360 (séance 1, jalon J1)
#
# Exécuté par : le PROPRIÉTAIRE du dépôt (chez nous : le rôle 1, seul membre avec GitHub Pro), connecté
#               avec SON compte (gh auth login). Le rôle 4, responsable du dépôt, lui fournit ce script.
#               Si le dépôt existe déjà, la création est sautée : seule la configuration est appliquée.
# Dépend de   : GitHub Pro sur le compte propriétaire (protection de main sur un dépôt PRIVÉ) ;
#               comptes GitHub des autres membres.
#
# Usage (depuis la racine du dépôt local, avant le premier push) :
#   gh auth login                                    # avec le compte GitHub du PROPRIÉTAIRE (rôle 1)
#   export MEMBRES="pseudo-role2 pseudo-role3 pseudo-role4 pseudo-role5"
#   export INTERVENANT="pseudo-intervenant"
#   bash scripts/github/init-depot.sh nexus360
# =============================================================================
set -euo pipefail
NOM="${1:-nexus360}"
: "${MEMBRES:?liste des comptes GitHub des 4 autres membres}"
: "${INTERVENANT:?compte GitHub (intervenant)}"
PROPRIO="$(gh api user --jq .login)"
R="$PROPRIO/$NOM"
echo ">> Propriétaire : $PROPRIO — dépôt : $R"

# --- 1. Dépôt privé + premier push de main
if ! gh repo view "$R" >/dev/null 2>&1; then
  [[ -d .git ]] || { git init -b main; git add -A; git commit -m "chore: structure initiale du dépôt Nexus360"; }
  gh repo create "$R" --private --description "Nexus360 — socle serveurs Linux/Windows (mission T01)" \
     --source=. --remote=origin --push
fi

# --- 2. Réglages : fusion par PR, suppression auto des branches fusionnées, pas de wiki
gh api -X PATCH "repos/$R" \
  -F delete_branch_on_merge=true -F allow_merge_commit=true -F allow_squash_merge=true \
  -F allow_rebase_merge=false -F has_wiki=false -F has_issues=true -F has_projects=true >/dev/null
echo ">> Réglages appliqués"

# --- 3. Collaborateurs (sur un dépôt personnel, tout collaborateur a les droits d'écriture ;
#        la protection de main empêche quand même tout push direct)
for u in $MEMBRES "$INTERVENANT"; do
  gh api -X PUT "repos/$R/collaborators/$u" -f permission=push >/dev/null && echo ">> Invitation envoyée à $u"
done

# --- 4. Étiquettes par rôle et par type
while IFS='|' read -r nom couleur desc; do
  gh label create "$nom" --repo "$R" --color "$couleur" --description "$desc" --force >/dev/null
done <<'EOF'
role-1-identite|1d76db|Rôle 1 : AD, DNS, DHCP, GPO, tiering, LAPS
role-2-windows|5319e7|Rôle 2 : partages, FSRM, WSUS, WEF, PowerShell
role-3-linux|0e8a16|Rôle 3 : Rocky/Ubuntu, Ansible base/web/ops, stockage, durcissement
role-4-exploitation|fbca04|Rôle 4 : pipeline, supervision, journaux, sauvegardes, DAT
role-5-reseau|d93f0b|Rôle 5 : passerelles, tailnet, relais DHCP, postes
tache|c5def5|Tâche du projet
incident|b60205|Panne ou incident (fiche annexe B)
dependance|f9d0c4|Bloqué par la tâche d'un autre rôle
documentation|0075ca|DAT, runbooks, PV
EOF
echo ">> Étiquettes créées"

# --- 5. Jalons (dates à ajuster au calendrier des séances)
for j in "J1 — fin séance 2" "J2 — avant séance 4" "J3 — fin séance 4" "J4 — fin séance 5" "Gel v1.0 — veille séance 6"; do
  gh api "repos/$R/milestones" -f title="$j" >/dev/null 2>&1 || true
done
echo ">> Jalons créés (ajouter les dates dans Issues > Milestones)"

# --- 6. Protection de main (exige GitHub Pro pour un dépôt privé)
if gh api -X PUT "repos/$R/branches/main/protection" --input - >/dev/null <<'EOF'
{
  "required_status_checks": { "strict": true, "contexts": ["Analyse statique"] },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
then
  echo ">> main protégée : PR + 1 approbation d'un propriétaire du code + analyse verte, même pour le propriétaire"
else
  echo "!! Protection refusée : le compte $PROPRIO n'a probablement pas GitHub Pro (Student Developer Pack)." >&2
  echo "!! Sans elle, la règle 'jamais de push direct sur main' repose sur la discipline : à noter au DAT." >&2
fi

# --- 7. Secrets du pipeline (saisis au clavier, jamais écrits dans un fichier)
echo ">> Saisir le mot de passe du coffre Ansible (ANSIBLE_VAULT_PASSWORD) :"
gh secret set ANSIBLE_VAULT_PASSWORD --repo "$R"
echo ">> (plus tard, quand Grafana tourne) gh secret set GRAFANA_TOKEN --repo $R"

cat <<EOF

Fini. Reste à faire à la main :
  1. Remplacer les @membre-roleN de .github/CODEOWNERS par les vrais comptes (PR).
  2. Quand le runner de LNX-OPS01 tourne (J3), ajouter le contrôle "Vérification à blanc (check / WhatIf)"
     aux contrôles obligatoires : Settings > Branches > main > Edit.
  3. Créer le tableau de suivi : Projects > New project > Board (colonnes À faire / En cours / En revue / Fait).
EOF
