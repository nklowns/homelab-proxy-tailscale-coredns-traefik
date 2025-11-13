#!/bin/bash
set -euo pipefail

DuckDNS_Token=${DUCKDNS_TOKEN:-""}
DOMAIN_DUCKDNS=${DOMAIN_DUCKDNS:-"drake-ayu.duckdns.org"}
ACME_EMAIL=${ACME_EMAIL:-"your.email+acme@domain.com"}

# Exporta a variável com o nome que o plugin espera
export DuckDNS_Token

if [[ -z "$DuckDNS_Token" ]]; then
  echo "ERRO: DuckDNS_Token não definido"
  exit 1
fi

echo "[INFO] Registrando conta no ZeroSSL com email: $ACME_EMAIL"
/root/.acme.sh/acme.sh \
  --register-account \
  -m "$ACME_EMAIL" \
  --server zerossl

if [[ ! -f "/certs/${DOMAIN_DUCKDNS}.key" ]]; then
  echo "[INFO] Primeira emissão"
  echo "[INFO] Emitindo certificado para: $DOMAIN_DUCKDNS"
  /root/.acme.sh/acme.sh \
    --issue \
    --dns dns_duckdns \
    --dnssleep 120 \
    -d "$DOMAIN_DUCKDNS" \
    -d "*.$DOMAIN_DUCKDNS" \
    --server zerossl

  echo "[INFO] Instalando certificados em /certs"
  /root/.acme.sh/acme.sh \
    --install-cert \
    -d "$DOMAIN_DUCKDNS" \
    -d "*.$DOMAIN_DUCKDNS" \
    --key-file "/certs/${DOMAIN_DUCKDNS}.key" \
    --fullchain-file "/certs/${DOMAIN_DUCKDNS}.crt" \
    --reloadcmd "echo [INFO] Certificado renovado para $DOMAIN_DUCKDNS"
else
  echo "[INFO] Certificado já existe, iniciando modo daemon"
fi

# Loop infinito para renovar todo dia
while true; do
  echo "[INFO] Rodando acme.sh --cron"
  /root/.acme.sh/acme.sh --cron
  sleep 12h
done
