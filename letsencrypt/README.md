# Let's Encrypt Certificate Storage

This directory is mounted at `/letsencrypt` inside the Traefik container to store ACME certificates obtained from Let's Encrypt.

## Configuration

The certificate resolver is configured as follows:

```yaml
certificatesResolvers:
    leresolverDuckdns:
        acme:
            storage: /letsencrypt/acme.json
```

## Files

- `acme.json`: Certificate storage file managed by Traefik. Must have 600 permissions.
