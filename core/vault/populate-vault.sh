#!/usr/bin/env bash
# populate-vault.sh
# Popula os paths de secrets no Vault para todos os apps.
# Execute APÓS vault-init job completar com sucesso.
#
# Uso:
#   export VAULT_ADDR=https://vault.justgui.dev
#   export VAULT_TOKEN=<root-token-do-init>
#   ./core/vault/populate-vault.sh
#
set -euo pipefail

: "${VAULT_ADDR:?Defina VAULT_ADDR}"
: "${VAULT_TOKEN:?Defina VAULT_TOKEN}"

echo "Populando secrets no Vault em $VAULT_ADDR..."

# ─── hericarealtor ──────────────────────────────────────────────────────────
vault kv put secret/hericarealtor \
  APP_KEY="${HERICAREALTOR_APP_KEY:?}" \
  DB_PASSWORD="${HERICAREALTOR_DB_PASSWORD:?}" \
  REDIS_PASSWORD="${HERICAREALTOR_REDIS_PASSWORD:?}" \
  AWS_ACCESS_KEY_ID="${MINIO_ACCESS_KEY:?}" \
  AWS_SECRET_ACCESS_KEY="${MINIO_SECRET_KEY:?}" \
  MAIL_USERNAME="${MAIL_USERNAME:-}" \
  MAIL_PASSWORD="${MAIL_PASSWORD:-}" \
  N8N_INTERNAL_TOKEN="${N8N_INTERNAL_TOKEN:?}"

echo "✓ secret/hericarealtor"

# ─── listings-updater ───────────────────────────────────────────────────────
vault kv put secret/listings-updater \
  DATABASE_URL="postgresql://hericarealtor:${HERICAREALTOR_DB_PASSWORD}@hericarealtor-postgres:5432/hericarealtor_db"

echo "✓ secret/listings-updater"

# ─── whatsapp-updater (tyer-chatwoot) ───────────────────────────────────────
vault kv put secret/whatsapp-updater \
  CHATWOOT_URL="${CHATWOOT_URL:?}" \
  CHATWOOT_API_TOKEN="${CHATWOOT_API_TOKEN:?}"

echo "✓ secret/whatsapp-updater"

# ─── cluster (MinIO root, SMTP, etc.) ───────────────────────────────────────
vault kv put secret/cluster/minio \
  MINIO_ROOT_USER="${MINIO_ROOT_USER:?}" \
  MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:?}"

echo "✓ secret/cluster/minio"

vault kv put secret/cluster/smtp \
  SMTP_HOST="${SMTP_HOST:?}" \
  SMTP_PORT="${SMTP_PORT:-587}" \
  SMTP_USER="${SMTP_USER:?}" \
  SMTP_PASSWORD="${SMTP_PASSWORD:?}"

echo "✓ secret/cluster/smtp"

# ─── authentik (OAuth providers) ────────────────────────────────────────────
# Os valores originais estavam em authentik-oauth-sources-sealed.yaml
# Obtenha os valores no console do GitHub/Google OAuth apps
vault kv put secret/cluster/authentik-oauth \
  github_client_id="${AUTHENTIK_GITHUB_CLIENT_ID:?}" \
  github_client_secret="${AUTHENTIK_GITHUB_CLIENT_SECRET:?}" \
  google_client_id="${AUTHENTIK_GOOGLE_CLIENT_ID:?}" \
  google_client_secret="${AUTHENTIK_GOOGLE_CLIENT_SECRET:?}"

echo "✓ secret/cluster/authentik-oauth"

# ─── n8n (API key para o workflow provisioner) ──────────────────────────────
# Gere uma chave segura: openssl rand -hex 32
vault kv put secret/cluster/n8n \
  N8N_API_KEY="${N8N_API_KEY:?}" \
  N8N_INTERNAL_TOKEN="${N8N_INTERNAL_TOKEN:?}"

echo "✓ secret/cluster/n8n"

echo ""
echo "Todos os secrets populados com sucesso!"
echo ""
echo "IMPORTANTE: salve as unseal keys e o root token em local seguro"
echo "e depois delete o Secret vault-init-keys do cluster:"
echo ""
echo "  kubectl delete secret vault-init-keys -n vault"
