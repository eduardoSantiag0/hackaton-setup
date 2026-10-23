#!/bin/bash
# admin/provisionar-grupos.sh
#
# SO O ORGANIZADOR roda este script, na VM. Ele:
#   1. Gera a chave do servidor (uma vez) e preenche admin/wg0.config
#   2. Gera a chave PRIVADA de cada grupo (voce quem gera, nao os grupos)
#   3. Adiciona um [Peer] por grupo em admin/wg0.config
#   4. Escreve em admin/emails/grupoN.txt um email pronto, com um bloco
#      ".env" que o grupo so precisa COLAR (sem editar nada)
#
# E idempotente: rodar de novo nao regenera chave de grupo que ja existe
# nem duplica peer no wg0.config.
#
# Uso:
#   ./provisionar-grupos.sh <IP_PUBLICO_DA_VM> <NUMERO_DE_GRUPOS> [PORTA]
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$DIR")"
KEYGEN="$ROOT/keygen.sh"
WG_CONF="$DIR/wg0.config"
KEYS_DIR="$DIR/chaves-privadas"
EMAILS_DIR="$DIR/emails"
MARKER="# >>> PEERS GERADOS POR provisionar-grupos.sh (nao editar a mao abaixo desta linha) <<<"

PUBLIC_IP="${1:-}"
NUM_GRUPOS="${2:-}"
WG_PORT="${3:-51820}"

if [ -z "$PUBLIC_IP" ] || [ -z "$NUM_GRUPOS" ]; then
  echo "Uso: $0 <IP_PUBLICO_DA_VM> <NUMERO_DE_GRUPOS> [PORTA_WIREGUARD]" >&2
  exit 1
fi
case "$NUM_GRUPOS" in
  *[!0-9]*|'') echo "NUMERO_DE_GRUPOS invalido: $NUM_GRUPOS" >&2; exit 1 ;;
esac
if [ ! -f "$KEYGEN" ]; then
  echo "Erro: nao encontrei $KEYGEN" >&2
  exit 1
fi
if [ ! -f "$WG_CONF" ]; then
  echo "Erro: nao encontrei $WG_CONF" >&2
  exit 1
fi

mkdir -p "$KEYS_DIR" "$EMAILS_DIR"

# 1. Chave do servidor (gera so se ainda for o placeholder)
SERVER_PRIV="$(grep '^PrivateKey = ' "$WG_CONF" | sed 's/^PrivateKey = //')"
if [ "$SERVER_PRIV" = "<PREENCHER_PRIVKEY_DO_SERVIDOR>" ] || [ -z "$SERVER_PRIV" ]; then
  SERVER_PRIV="$("$KEYGEN" genkey)"
  sed -i "s|^PrivateKey = .*|PrivateKey = $SERVER_PRIV|" "$WG_CONF"
  echo "Chave do servidor gerada e salva em admin/wg0.config"
fi
SERVER_PUB="$("$KEYGEN" pubkey "$SERVER_PRIV")"

if ! grep -qF "$MARKER" "$WG_CONF"; then
  printf '\n%s\n' "$MARKER" >> "$WG_CONF"
fi

echo
printf '%-10s %-16s %-16s\n' "GRUPO" "IP_VPN" "IP_CONTAINER"

for i in $(seq 1 "$NUM_GRUPOS"); do
  NAME="grupo$i"
  SUFFIX=$((10 + i))
  VPN_IP="10.13.13.$SUFFIX"
  CONTAINER_IP="172.28.10.$SUFFIX"

  PRIV_FILE="$KEYS_DIR/$NAME-privkey.txt"
  if [ -f "$PRIV_FILE" ]; then
    PRIV="$(cat "$PRIV_FILE")"
  else
    PRIV="$("$KEYGEN" genkey)"
    printf '%s\n' "$PRIV" > "$PRIV_FILE"
    chmod 600 "$PRIV_FILE"
  fi
  PUB="$("$KEYGEN" pubkey "$PRIV")"

  if ! grep -qF "# $NAME" "$WG_CONF"; then
    cat >> "$WG_CONF" <<PEER

[Peer]
# $NAME
PublicKey = $PUB
AllowedIPs = $VPN_IP/32
PEER
  fi

  cat > "$EMAILS_DIR/$NAME.txt" <<EMAIL
Assunto: Acesso VPN - Hackathon - $NAME

Ola, $NAME!

Para acessar o ambiente do hackathon:

1. Peguem a pasta "grupo-template" (tem os arquivos gerar-conf.sh e
   .env.example).
2. Dentro dela, criem um arquivo chamado ".env" e colem exatamente o
   bloco abaixo (sem editar nada):

PRIVATE_KEY=$PRIV
ADDRESS=$VPN_IP/32
SERVER_PUBLIC_KEY=$SERVER_PUB
ENDPOINT=$PUBLIC_IP:$WG_PORT
ALLOWED_IPS=10.13.13.0/24,172.28.10.0/24

3. Rodem: ./gerar-conf.sh
4. Importem o arquivo wg0.conf gerado no app do WireGuard e ativem a VPN.
5. Com a VPN ativa, o ambiente de voces fica em $CONTAINER_IP, na porta
   que a aplicacao de voces escutar dentro do container.

Boa sorte no hackathon!
EMAIL

  printf '%-10s %-16s %-16s\n' "$NAME" "$VPN_IP" "$CONTAINER_IP"
done

echo
echo "Chave publica do servidor: $SERVER_PUB"
echo "Emails prontos em: admin/emails/grupoN.txt (copie o conteudo e envie por email)"
echo "Chaves privadas guardadas em: admin/chaves-privadas/ (NAO compartilhar, NAO versionar)"
echo
echo "Agora reinicie o wireguard: docker compose restart wireguard"
