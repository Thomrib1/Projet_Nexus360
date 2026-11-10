#!/usr/bin/env bash
# Fournit le mot de passe du coffre Ansible à partir de l'environnement.
# - En CI : secret GitHub ANSIBLE_VAULT_PASSWORD injecté dans l'environnement du job.
# - En manuel sur LNX-OPS01 : fichier /etc/nexus360/vault-pass (root:ansible 0640), hors dépôt.
set -euo pipefail
if [[ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
  printf '%s\n' "$ANSIBLE_VAULT_PASSWORD"
elif [[ -r /etc/nexus360/vault-pass ]]; then
  cat /etc/nexus360/vault-pass
else
  echo "Mot de passe du coffre introuvable (ANSIBLE_VAULT_PASSWORD ou /etc/nexus360/vault-pass)" >&2
  exit 1
fi
