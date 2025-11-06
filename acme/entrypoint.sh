#!/bin/bash
set -euo pipefail

DOMAIN=${DOMAIN:-"drake-ayu.duckdns.org"}
EMAIL=${EMAIL:-"nklowns@gmail.com"}
DuckDNS_Token=${DUCKDNS_TOKEN:-""}

# Exporta a variável com o nome que o plugin espera
export DuckDNS_Token

if [[ -z "$DuckDNS_Token" ]]; then
  echo "ERRO: DUCKDNS_TOKEN não definido"
  exit 1
fi

echo "[INFO] Registrando conta no ZeroSSL com email: $EMAIL"
/root/.acme.sh/acme.sh --register-account -m "$EMAIL" --server zerossl

if [[ ! -f /certs/$DOMAIN.key ]]; then
  echo "[INFO] Primeira emissão"
  echo "[INFO] Emitindo certificado para: $DOMAIN"
  /root/.acme.sh/acme.sh --issue \
    --dns dns_duckdns \
    -d "$DOMAIN" \
    --server zerossl \
    --yes-I-know-dns-manual-mode-enough-go-ahead-please

  echo "[INFO] Instalando certificados em /certs"
  /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --key-file /certs/$DOMAIN.key \
    --fullchain-file /certs/$DOMAIN.crt \
    --reloadcmd "echo [INFO] Certificado renovado para $DOMAIN"
else
  echo "[INFO] Certificado já existe, iniciando modo daemon"
fi

# Loop infinito para renovar todo dia
while true; do
  echo "[INFO] Rodando acme.sh --cron"
  /root/.acme.sh/acme.sh --cron
  sleep 12h
done
