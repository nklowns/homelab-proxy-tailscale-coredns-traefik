# Local Certificates Directory

This directory is used to store local TLS certificates for internal domains (e.g., `DOMAIN_LOCAL` and `DOMAIN_DUCKDNS`).

## Certificate Sources

Certificates can be obtained from:

1. **ACME Service (acme-duckdns container)**: The `acme-duckdns` service generates certificates for your DuckDNS domain and stores them here.
2. **Manual Generation**: You can manually generate self-signed certificates for local development.

## Required Files

The Traefik dynamic configuration expects these files:

- `${DOMAIN_DUCKDNS}.crt`: Certificate file for your DuckDNS domain
- `${DOMAIN_DUCKDNS}.key`: Private key file for your DuckDNS domain

## Generating Self-Signed Certificates (for local development)

If you want to use self-signed certificates for local development:

```bash
# Replace drake-ayu.duckdns.org with your domain
DOMAIN="drake-ayu.duckdns.org"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${DOMAIN}.key" \
  -out "${DOMAIN}.crt" \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN}"
```

## Note

- The `acme-duckdns` service in `docker-compose.yml` will automatically generate and renew certificates.
- Traefik also has its own ACME resolver (`leresolverDuckdns`) which stores certificates in `/letsencrypt/acme.json`.
- The certificates in this directory are used as static certificates in the Traefik configuration.
