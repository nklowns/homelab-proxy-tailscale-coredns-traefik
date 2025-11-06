# homelab-proxy-tailscale-coredns-traefik

Stack de proxy reverso para homelab usando Traefik + Tailscale + CoreDNS + Docker Socket Proxy + ACME/Let's Encrypt/DuckDNS, com foco em:

- Acesso seguro via tailnet (Tailscale) sem expor portas na Internet
- DNS local e de domínio dinâmico (DuckDNS) usando CoreDNS
- Emissão automática de certificados (DNS-01 DuckDNS) + certificados locais
- Configuração dinâmica com descoberta de containers via Docker API protegida
- Observabilidade (dashboard, access log) e modularidade

## 🆕 V2 Features

- **Profiles**: Use Docker Compose profiles para controlar quais serviços iniciar (`core`, `dns`, `demo`, `tools`, `acme-ext`)
- **Image Pinning**: Versões de imagens fixadas em `.env` para reprodutibilidade
- **Security by Default**: Docker API não exposta por padrão; permissões mínimas no socket proxy
- **Automation**: Makefile e scripts para bootstrap, validação e operações comuns
- **Healthchecks**: Todos os serviços principais têm healthchecks configurados
- **Better Defaults**: Log level configurável, métricas opcionais, configuração parametrizada

---
## 🧱 Arquitetura

```
┌──────────────────────────────────────────────────────────┐
│                      Tailnet (Tailscale)                 │
│  (rede privada mesh, autenticação, DNS mágico, ACLs)     │
└───────────────▲───────────────────────────────▲──────────┘
                │                               │
        (network_mode: service:proxy-tailscale) │
                │                               │
        ┌───────┴────────┐               ┌──────┴──────────┐
        │ proxy-tailscale│               │ proxy-coredns   │
        │ (tailscaled)   │◄──────────────┤ CoreDNS         │
        └───────▲────────┘               └──────┬──────────┘
                │ network stack partilhado      │ DNS (A/AAAA/HTTPS/SVCB)
                │                               │
        ┌───────┴────────┐                      │
        │ proxy-traefik  │◄─────────────────────┘
        │ Traefik
        │  - entryPoints
        │  - ACME (DuckDNS DNS-01)
        │  - Tailscale certs (tailsolver)
        │  - File + Docker providers
        └───────▲────────┘
                │
                │ (proxy_net)
        ┌───────┴──────────┐     ┌─────────────────────┐
        │ docker-socket-   │     │ whoami (exemplo)     │
        │ proxy            │     │ qualquer outro svc   │
        └──────────────────┘     └─────────────────────┘
```

---
## 📂 Estrutura de Pastas

| Caminho | Descrição |
|---------|-----------|
| `docker-compose.yml`  | Orquestra todos os serviços. |
| `traefik.yml`         | Configuração estática (entryPoints, providers, ACME). |
| `traefik-dynamic.yml` | Configuração dinâmica (routers extras, TLS local). |
| `Corefile`            | Regras do CoreDNS para domínios DuckDNS, Tailscale e `.local`. |
| `certs/`              | Certificados locais (ex.: `drake-ayu.local.*`). |
| `letsencrypt/`        | Armazena `acme.json` (persistência ACME). |
| `logs/`               | Logs de acesso (`access.log`). |
| `acme/`               | Dockerfile + script para emissão manual/externa (opcional). |
| `tailscale/`          | Estado e socket do Tailscale (`data/`, `tailscaled.sock`). |
| `.env.example`        | Variáveis de ambiente modelo. |

---
## ✅ Requisitos

- Docker + Docker Compose
- Conta DuckDNS (token)
- Conta Tailscale (auth key se usar key-based auth)

---
## 🚀 Uso Rápido (V2)

### Primeira vez (Bootstrap)

1. Clone o repositório:
   ```bash
   git clone <repo-url>
   cd homelab-proxy-tailscale-coredns-traefik
   ```

2. Execute o bootstrap:
   ```bash
   make bootstrap
   # ou manualmente:
   ./scripts/bootstrap.sh
   ```

3. Edite o `.env` com suas credenciais:
   ```bash
   nano .env
   # Configure: DUCKDNS_TOKEN, TS_AUTHKEY, MY_DOMAIN_DUCKDNS, etc.
   ```

4. Inicie os serviços:
   ```bash
   # Minimal (core services only)
   make up-core
   
   # With DNS
   make up PROFILES="core dns"
   
   # Full stack (core + dns + demo)
   make up-full
   ```

### Uso diário

```bash
# Ver ajuda
make help

# Iniciar serviços
make up

# Parar serviços
make down

# Ver logs
make logs

# Verificar saúde
make health

# Validar configuração
./scripts/checks.sh
```

### Profiles disponíveis

- `core`: Tailscale + Traefik + Docker Socket Proxy (minimal)
- `dns`: Adiciona CoreDNS para resolução DNS local
- `demo`: Adiciona serviço de exemplo (whoami)
- `tools`: Habilita exposição da Docker API (⚠️ usar com cuidado!)
- `acme-ext`: Container ACME externo para emissão manual de certificados

Exemplo:
```bash
# Apenas core
make up PROFILES="core"

# Core + DNS + Demo
make up PROFILES="core dns demo"
```

---
## 🔐 Variáveis de Ambiente (`.env`)

O arquivo `.env.example` contém todas as variáveis configuráveis:

| Categoria | Variável | Descrição |
|-----------|----------|-----------|
| **Geral** | `TZ` | Timezone para containers |
| **Imagens** | `TRAEFIK_IMAGE` | Versão do Traefik (default: v3.1) |
| | `COREDNS_IMAGE` | Versão do CoreDNS (default: 1.11.1) |
| | `TAILSCALE_IMAGE` | Versão do Tailscale (default: v1.74.0) |
| **Traefik** | `TRAEFIK_LOG_LEVEL` | Nível de log (INFO, DEBUG, etc.) |
| | `TRAEFIK_METRICS_ENABLED` | Habilitar métricas Prometheus |
| **DNS/ACME** | `DUCKDNS_TOKEN` | Token DuckDNS para DNS-01 challenge |
| | `EMAIL` / `ACME_EMAIL` | Email para registro ACME |
| | `MY_DOMAIN_DUCKDNS` | Domínio DuckDNS base |
| | `MY_DOMAIN_LOCAL` | Domínio local (.local) |
| | `TAILNET_HOSTNAME` | Nome do host na tailnet |
| | `TAILNET_IPV4_HINT` | IP IPv4 da tailnet (para CoreDNS) |
| | `ACME_CA_SERVER` | Use 'staging' ou 'production' |
| **Tailscale** | `TS_AUTHKEY` | Chave de autenticação Tailscale |

---
## 🌐 Traefik
### EntryPoints
- `web` (80) redireciona para `websecure` (HTTPS)
- `websecure` (443) usa `certResolver=leresolver`
- `docker-tcp` (2375) expõe Docker API via TCP (controlado por labels) — protegido pela tailnet
- `mongodb-tcp` (27017) placeholder para serviços TCP futuros

### Providers
- Docker: via `docker-socket-proxy` (reduz superfície de ataque)
- File: `traefik-dynamic.yml` para routers extras e certificados locais

### Certificados
- `leresolver`: ACME DNS-01 DuckDNS (Let's Encrypt / ZeroSSL dependendo do servidor)
- `tailsolver`: integração Tailscale (certificados emitidos pela API Tailscale)
- Cert local manual em `tls.certificates` (útil para domínio `.local`)

---
## 🔒 Tailscale
- `proxy-tailscale` roda `tailscaled` e compartilha o network namespace com Traefik e CoreDNS (`network_mode: service:proxy-tailscale`).
- Benefícios: IP tailnet, cert Tailscale (`tailsolver`), ACLs e DNS mágico.
- Estado persistido em `tailscale/data`.

Se não usar `TS_AUTHKEY`, entre no container e faça:
```bash
docker exec -it proxy-tailscale tailscale up
```

---
## 🧾 CoreDNS
`Corefile` responde para:
- `*.drake-ayu.ts.net`
- `*.drake-ayu.duckdns.org`
- `*.drake-ayu.local`

Com templates A/AAAA e registros HTTPS/SVCB apontando para o endereço IPv4 tailnet (`100.124.118.27`). Ajuste se o IP mudar.

Para testar:
```bash
docker exec -it proxy-coredns dig @127.0.0.1 whoami.drake-ayu.duckdns.org A
```

---
## 🔑 ACME / Certificados
### Via Traefik (principal)
- DNS-01 DuckDNS: requer `DUCKDNS_TOKEN`.
- Armazenamento em `letsencrypt/acme.json` (permissões preservadas).
  Se estiver vazio, Traefik cria/atualiza automaticamente.

### Via Container ACME externo (opcional)
- Diretório `acme/` contém `Dockerfile` + `entrypoint.sh` usando `acme.sh` e ZeroSSL.
- Comentado no `docker-compose.yml`. Para ativar:
  1. Descomente o serviço `acme-duckdns`.
  2. Ajuste variáveis `DUCKDNS_TOKEN`, `DOMAIN`, `EMAIL`.
  3. Suba novamente:
     ```bash
     docker compose up -d --build acme-duckdns
     ```

---
## ➕ Adicionando um Novo Serviço
No novo container (mesma rede `proxy_net`):
```yaml
labels:
  - traefik.enable=true
  - traefik.http.services.meuapp.loadbalancer.server.port=8080
  - traefik.http.routers.meuapp.rule=Host(`meuapp.${MY_DOMAIN_DUCKDNS}`) || Host(`meuapp.${MY_DOMAIN_LOCAL}`)
  - traefik.http.routers.meuapp.entrypoints=websecure
```
Se precisar de middleware (auth básica, headers, rate limit), adicione em `traefik-dynamic.yml` ou via labels.

---
## 🛠 Troubleshooting

| Sintoma | Ação |
|---------|------|
| Cert não emite (ACME) | Verificar `DUCKDNS_TOKEN`; usar `ACME_CA_SERVER=staging` para testes; conferir logs Traefik |
| whoami não resolve | Testar DNS local; verificar CoreDNS logs; validar se serviço está no profile correto |
| Tailscale unhealthy | `docker logs proxy-tailscale`; checar chave / políticas ACL |
| Dashboard sem acesso | Confirmar domínio em `traefik-dynamic.yml` e DNS apontando; verificar se Traefik está rodando |
| Docker API exposta | Verificar se profile `tools` está ativo; remover profile e reiniciar |
| Permissões em acme.json | Executar `make acme-perms` ou `chmod 600 letsencrypt/acme.json` |
| Serviço não inicia | Verificar profiles: `make ps`; confirmar que profile correto está ativo |

### Comandos úteis

```bash
# Validar configuração
./scripts/checks.sh

# Ver status detalhado
make health

# Logs em tempo real
make dev-logs

# Acessar shell nos containers
make shell-traefik
make shell-tailscale
make shell-coredns

# Testar DNS
make test-dns
```

---
## 🔐 Segurança (V2 Improvements)

### Implementadas por padrão
- ✅ Docker Socket Proxy com permissões mínimas (apenas CONTAINERS, NETWORKS, SERVICES, TASKS)
- ✅ Docker API **não exposta** por padrão (movida para profile `tools`)
- ✅ `acme.json` com permissões 600 (configurado pelo bootstrap)
- ✅ Versões de imagens fixadas (não usa `:latest` em produção)
- ✅ Healthchecks em todos os serviços principais

### Checklist de Segurança
- [ ] Rotacione `DUCKDNS_TOKEN` periodicamente
- [ ] Use ACLs no painel Tailscale para limitar acesso
- [ ] Revise permissões do `docker-socket-proxy` periodicamente
- [ ] Não exponha portas host (usa tailnet + network_mode compartilhado)
- [ ] Proteja o dashboard Traefik com auth/middlewares se necessário
- [ ] Use `ACME_CA_SERVER=staging` durante testes para evitar rate limits
- [ ] Ative o profile `tools` **apenas quando necessário** para debugging

### Expondo Docker API (CUIDADO!)

Por padrão, a Docker API **não está acessível via HTTP/TCP**. Se você precisa expor para debugging:

```bash
# Iniciar com profile tools (inclui exposição da API)
make up PROFILES="core tools"

# IMPORTANTE: Use apenas em ambientes seguros e isolados!
# Reverta após debugging:
make down
make up PROFILES="core dns"
```

---
## 🧪 Testes Rápidos
```bash
# Ver routers carregados
curl -s --cacert certs/drake-ayu.local.crt https://traefik.drake-ayu.local/api/http/routers | jq 'keys'

# Checar certificados armazenados
docker exec -it proxy-traefik ls -l /letsencrypt
```

---
## 🗺 Roadmap / Ideias Futuras

Ver [ROADMAP.md](ROADMAP.md) para plano detalhado da V2.

**V2.0.0 (Implementado):**
- ✅ Profiles de Compose (core, dns, demo, tools, acme-ext)
- ✅ Pinagem de versões de imagens
- ✅ Segurança: Docker API não exposta por padrão
- ✅ Healthchecks em todos os serviços
- ✅ Makefile para automação
- ✅ Scripts de bootstrap e validação
- ✅ Log level configurável

**Próximos passos (V2.1+):**
- Templates de configuração com envsubst
- Middleware de autenticação central
- Integração com Grafana/Loki
- Suporte a Tailscale Services
- Multi-ambiente (.env.dev, .env.prod)

---
## ⚖️ Licença
Defina uma licença (ex.: MIT) se for público.

---
## 🙌 Contribuição
PRs e sugestões são bem-vindos. Abra uma issue com ideias ou problemas.

---
## 📎 Notas
- Ajuste todos os domínios para o seu ambiente antes de uso em produção.
- O IP tailnet em `Corefile` deve ser atualizado se mudar.

---
## ✨ Resumo
Este repositório fornece um ponto de partida sólido para expor serviços internos com segurança através de Traefik + Tailscale, resolvendo nomes e certificados automaticamente e mantendo a superfície mínima exposta à Internet.
