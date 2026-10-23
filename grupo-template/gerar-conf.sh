#!/bin/bash
# gerar-conf.sh
#
# Rode isso depois de colar, no arquivo .env (nesta mesma pasta), o bloco
# que o organizador do hackathon mandou por email. Gera wg0.conf, usado
# pelo docker-compose.yaml desta pasta para subir a VPN num container
# (sem precisar instalar o WireGuard na sua maquina).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Nao encontrei $ENV_FILE" >&2
  echo "Crie um arquivo .env nesta pasta e cole ali o bloco que veio no email do organizador." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${PRIVATE_KEY:?Faltou PRIVATE_KEY no .env}"
: "${ADDRESS:?Faltou ADDRESS no .env}"
: "${SERVER_PUBLIC_KEY:?Faltou SERVER_PUBLIC_KEY no .env}"
: "${ENDPOINT:?Faltou ENDPOINT no .env}"
: "${ALLOWED_IPS:?Faltou ALLOWED_IPS no .env}"

OUT="$DIR/wg0.conf"
cat > "$OUT" <<EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ADDRESS

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $ENDPOINT
AllowedIPs = $ALLOWED_IPS
PersistentKeepalive = 25
EOF

echo "Gerado: $OUT"
echo "Agora rode: docker compose up -d"
echo "Depois acesse a aplicacao do grupo em: http://localhost:8080"
