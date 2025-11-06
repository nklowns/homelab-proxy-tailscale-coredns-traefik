# Roadmap V2 — homelab-proxy-tailscale-coredns-traefik

Este documento analisa o estado atual da stack e propõe uma V2 focada em replicabilidade entre ambientes (local/dev/staging/prod), simplicidade operacional e segurança.

Referências técnicas (Context7):
- Traefik (entryPoints, providers, ACME, Tailscale certs): /traefik/traefik
- Tailscale (certificados automáticos, serve/funnel): /tailscale/tailscale
- CoreDNS (plugin template, registros HTTPS/SVCB): /coredns/coredns

Atualização (Serviços Tailscale): Considerar a funcionalidade "Tailscale Services" para anunciar serviços internos sem necessidade de roteamento HTTP avançado.

---
## 1) O que já foi feito (Estado atual)

- Orquestração
  - Compose com rede externa `proxy_net` e serviços principais:
    - `proxy-tailscale` (tailscaled) com saúde (tailscale status), volumes persistentes, capacidades e `/dev/net/tun`.
    - `proxy-coredns` (CoreDNS) e `proxy-traefik` compartilhando o namespace de rede do Tailscale (`network_mode: service:proxy-tailscale`), ouvindo na tailnet.
    - `docker-socket-proxy` (Docker API minimamente exposta ao Traefik via TCP interno).
    - `whoami` (exemplo) na rede `proxy_net`.
- Traefik
  - EntryPoints: `web` (80) -> redirect para `websecure` (443), TCP extras (2375/27017).
  - Providers: `docker` via socket-proxy e `file` (`traefik-dynamic.yml`).
  - Certificados:
    - ACME DNS-01 DuckDNS (`leresolver`) com resolvers públicos (Cloudflare/Google) [ref: ACME DNS-01].
    - `tailsolver` (certificados pela API Tailscale) [ref: Tailscale resolver].
  - Dashboard habilitado, access log e logs em DEBUG.
- CoreDNS
  - Uso do plugin `template` para responder A/AAAA/HTTPS/SVCB aos domínios: `*.ts.net`, `*.duckdns.org`, `*.local` [ref: template plugin].
  - IP tailnet IPv4 fixo no `Corefile` (100.124.118.27).
- ACME externo (opcional)
  - Pasta `acme/` com `acme.sh` (ZeroSSL) e `entrypoint.sh` para emissão/renovação via DuckDNS DNS-01.
- Variáveis de ambiente
  - `.env.example` com `DUCKDNS_TOKEN`, `TS_AUTHKEY`, `MY_DOMAIN_*`, `EMAIL`, `TZ`.

Observação de conectividade: ao usar `network_mode: service:proxy-tailscale`, o Traefik compartilha as mesmas redes do container `proxy-tailscale`. Como `proxy-tailscale` está na `proxy_net`, o Traefik alcança serviços nessa rede (e também escuta na interface tailnet).

---
## 2) Pontos fortes e riscos

Pontos fortes
- Tráfego de entrada focado na tailnet (superfície de ataque reduzida).
- ACME por DNS (evita abertura de portas 80/443 na Internet).
- Providers bem definidos (docker + file) e rota de exemplo funcional.
- Socket-proxy reduz privilégios comparado a mapear `/var/run/docker.sock` direto.

Riscos / Oportunidades de melhoria
- DNS/IP hardcoded: `Corefile` fixa o IP tailnet. Mudanças de IP exigem alteração manual.
- Multiplicidade de domínios fixos em `traefik.yml`/`traefik-dynamic.yml` (dificulta replicar em outro ambiente/domínio).
- Exposição da Docker API via Traefik (labels HTTP/TCP). Em muitos cenários, isso não deve ser exposto, nem na tailnet.
- Logs em DEBUG por padrão (ruído e custo). Melhor ter perfil/variável para nível de log.
- Segurança do `acme.json` (permissão 600 recomendada) e rotação de tokens.
- Healthcheck ausente para CoreDNS (viabilidade de adicionar um `dig` simples).
- Versionamento de imagens `:latest` (replicabilidade menor). Ideal pinagem de versões.

---
## 3) Objetivos da V2

- Replicabilidade multi-ambientes (local/dev/staging/prod) com zero code changes — apenas `.env` e seleção de perfis.
- Parametrização completa de domínios/IPs/certs por variáveis.
- Segurança por padrão: nada exposto desnecessariamente; dashboards protegidos.
- Observabilidade básica opcional (perfis), mantendo a base enxuta.
- Automação mínima (Makefile/scripts) para bootstrap e validações.
 - Planejar coexistência ou eventual migração parcial para Tailscale Services em serviços simples.

---
## 4) Proposta de Arquitetura V2

### 4.1 Perfis de Compose (profiles)
- `core` (default): `proxy-tailscale`, `proxy-traefik`, `docker-socket-proxy`.
- `dns`: `proxy-coredns` (habilitar quando desejar DNS autoritativo local).
- `acme-ext`: `acme-duckdns` (emissão externa com acme.sh, opcional).
- `demo`: exemplos (`whoami`).
- `obs`: observabilidade (ex.: Prometheus scrape do Traefik, Loki/Promtail, habilitados por perfil).

Uso: `docker compose --profile core --profile dns up -d`

### 4.2 Template de configuração (envsubst)
- Substituir hardcodes por templates renderizados em runtime:
  - `config/traefik.yml.tmpl`, `config/traefik-dynamic.yml.tmpl`, `config/Corefile.tmpl`.
  - Script `scripts/render-config.sh` roda `envsubst` e gera arquivos finais montados no container.
- Variáveis sugeridas:
  - `DOMAIN_DUCKDNS`, `DOMAIN_LOCAL`, `TAILNET_HOSTNAME`, `TAILNET_IPV4_HINT` (opcional), `ACME_EMAIL`, `ACME_CA_SERVER` (staging/prod), `TRAEFIK_LOG_LEVEL`, `TRAEFIK_METRICS`.

### 4.3 Certificados e ACME
- ACME Traefik
  - Toggle staging: variável para `caServer` (descomentar quando staging). [ref: ACME]
  - `dnsChallenge.delayBeforeCheck` conforme latência do DuckDNS.
- Tailscale certificates
  - Manter `tailsolver` para serviços internos no domínio `*.ts.net`. [ref: Tailscale resolver]
- Certificados locais (.local)
  - Continuar suporte via `tls.certificates` (útil em dev) parametrizado por env.

### 4.4 Segurança por padrão
- Remover (ou mover para perfil `tools`) os roteadores que expõem Docker API via HTTP/TCP.
- Proteção do dashboard Traefik: habilitar middleware BasicAuth (hash em `.env`), ou restringir a tailnet estritamente.
- `letsencrypt/acme.json` com permissão 600 (script de bootstrap ajusta).
- Reduzir permissões do `docker-socket-proxy` às estritamente necessárias (variáveis OFF por padrão, habilitar sob demanda).

### 4.5 Observabilidade opcional
- Traefik metrics endpoint (Prometheus) controlado por env/perfil.
- Logs JSON com rotação (montar `logs/` + política de log do Docker).
- Perfil `obs` pode adicionar Prometheus/Grafana/Loki se desejado.

### 4.6 Healthchecks e sanidade
- CoreDNS: healthcheck executando `dig @127.0.0.1 example.${DOMAIN_LOCAL} A`.
- Traefik: healthcheck `:8080/ping` (habilitar API ping) ou consulta simples.
- Tailscale: manter `tailscale status`.

### 4.7 Versões e pinagem
- Evitar `:latest`. Definir versões em `.env` (ex.: `TRAEFIK_IMAGE=traefik:v3.1`, `COREDNS_IMAGE=coredns/coredns:1.11.1`, `TAILSCALE_IMAGE=tailscale/tailscale:v1.74.0`).
- `docker-compose.yml` referencia `${TRAEFIK_IMAGE}` etc.

### 4.8 Automação de bootstrap
- Makefile com alvos:
  - `make render` (gera configs via envsubst)
  - `make up` / `make down`
  - `make network` (cria `proxy_net` se não existir)
  - `make acme-perms` (chmod 600 em `letsencrypt/acme.json`)
  - `make logs` (seguidores dos principais serviços)
- Script `scripts/checks.sh`: verifica Docker, rede, arquivos necessários, permissões.

### 4.9 Multi-ambiente (sem código duplicado)
- `.env.local`, `.env.dev`, `.env.staging`, `.env.prod` — e uso com `direnv` ou `dotenvx`.
- Ou `docker compose --env-file .env.staging ...`.
- Domínios parametrizados, sem hardcodes em YAML/Corefile.

### 4.10 (Opcional) Alternativa com `tailscale serve`
- Em vez de compartilhar namespace, pode-se:
  - Rodar Traefik apenas em `proxy_net`.
  - Usar `tailscale serve https:443 http://traefik:443` dentro do `proxy-tailscale`.
  - Vantagem: simplifica múltiplas redes/attachments; desvantagem: muda o modelo de terminação TLS e precisa ajustar healthchecks.
  - Referência: `tailscale serve` (CLI) e `tsnet.ListenTLS` [ref: Tailscale].

### 4.11 Integração / Coexistência com Tailscale Services
Tailscale Services (novo recurso) permite anunciar portas diretamente na tailnet. Estratégia:
- Serviços somente internos (sem necessidade de subdomínio público, sem middlewares complexos) podem ser anunciados pelo Services.
- Traefik permanece para: roteamento HTTP avançado (path, rewrite), subdomínios públicos (DuckDNS), middlewares, certificados públicos e edge policies.
- Gradualmente mover serviços elegíveis para Services reduz número de roteadores e dependência de certificados públicos.

Critérios para migração de um serviço para Services:
1. Apenas acesso interno tailnet.
2. Porta única, sem necessidade de host/path multiplex.
3. Não depende de middlewares Traefik (auth, rate limit, headers) ou eles podem ser substituídos por ACLs Tailscale.
4. TLS público não requerido.

Status esperado pós-migração parcial:
- Traefik: menos routers, foco em público/edge.
- Services: catálogos de serviços internos com ACL centralizada.

---
## 5) Plano faseado

MVP (V2.0.0)
1. Adicionar perfis de Compose (`core`, `dns`, `demo`, `acme-ext`).
2. Remover exposição da Docker API (mover para `tools`/`demo` ou desabilitar por padrão).
3. Pinagem das imagens via `.env`.
4. Script de bootstrap (network + acme perms) e Makefile básico.
5. Middleware de auth no dashboard (opcional por env) e `log.level` controlado por env.

V2.1 – Parametrização e Templates
1. Introduzir templates `*.tmpl` e `envsubst` no startup.
2. Variáveis para domínios, emails ACME, CA staging, IPv4 hint do CoreDNS.
3. Healthcheck para CoreDNS.

V2.2 – Observabilidade e Hardening
1. Habilitar métricas do Traefik (Prometheus) e logs JSON.
2. Perfil `obs` com Prometheus (scrape do Traefik) e dashboards básicos.
3. Reduzir permissões do `docker-socket-proxy` e documentar mínimo necessário para o provider.

V2.3 – Multi-ambientes e DX
1. Documentar `.env.*` e `--env-file` por ambiente.
2. Incluir exemplos de middlewares (BasicAuth, RateLimit, Headers) reutilizáveis.
3. Scripts de validação (`scripts/checks.sh`) e testes rápidos.

V2.4 – Extras (opcionais)
- `tailscale serve` flow alternativo.
- Integração com Grafana/Loki.
- ForwardAuth (OIDC) para serviços sensíveis.
 - Migração de mais serviços internos para Tailscale Services e remoção de roteadores redundantes.

V2.5 – Consolidação (se aplicável)
- Inventário final de serviços ainda sob Traefik; justificar cada um.
- Automatizar script que lista candidatos a migrar (verifica labels simples e porta).
- Limpeza de middlewares não usados.

---
## 6) Ações rápidas (low hanging fruit)
- [ ] Pinagem de versões das imagens via `.env`.
- [ ] Remover/externalizar roteadores que expõem Docker API.
- [ ] `letsencrypt/acme.json` com permissão 600 (script/Makefile).
- [ ] `TRAEFIK_LOG_LEVEL` configurable (INFO por padrão).
- [ ] Healthcheck do CoreDNS.
 - [ ] Remover/segregar roteadores da Docker API em perfil "tools".
 - [ ] Criar middleware `secure-defaults` (headers + compressão).
 - [ ] Adicionar pinagem de imagens em `.env`.
 - [ ] Documentar uso inicial de Tailscale Services (expor whoami interno sem Traefik).

---
## 7) Critérios de sucesso
- Subir/derrubar ambientes diferentes trocando apenas `--env-file` e `--profile`.
- Nenhum hardcode de domínio/IP em YAML/Corefile (tudo via env ou templates).
- Sem exposição inadvertida de APIs (Docker/Traefik) fora da tailnet.
- Certificados emitidos automaticamente (DNS-01 e/ou Tailscale) sem intervenção manual.

---
## 8) Notas finais
- O design atual (compartilhamento do namespace de rede do Tailscale) é sólido para acesso na tailnet e alcança os serviços na `proxy_net`. Para replicabilidade, priorize parametrização e perfis.
- Se a tailnet IPv4 mudar com frequência, prefira derivar esse valor dinamicamente (ex.: script que descobre o IP do `tailscale ip -4` e o injeta no Corefile via template).
 - Tailscale Services pode reduzir a necessidade de configurar roteadores e certificados para serviços estritamente internos.
