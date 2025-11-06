# homelab-proxy-tailscale-coredns-traefik

Stack de proxy reverso para homelab usando Traefik + Tailscale + CoreDNS + Docker Socket Proxy + ACME/Let's Encrypt/DuckDNS, com foco em:

- Acesso seguro via tailnet (Tailscale) sem expor portas na Internet
- DNS local e de domínio dinâmico (DuckDNS) usando CoreDNS
- Emissão automática de certificados (DNS-01 DuckDNS) + certificados locais
- Configuração dinâmica com descoberta de containers via Docker API protegida
- Observabilidade (dashboard, access log) e modularidade

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
- Rede Docker externa pré-criada: `proxy_net`
  Criar se não existir:
  ```bash
  docker network create proxy_net
  ```
- Conta DuckDNS (token)
- Conta Tailscale (auth key se usar key-based auth)

---
## 🔐 Variáveis de Ambiente (`.env`)
Baseado em `.env.example`:

| Variável | Função |
|----------|--------|
| `TZ`                 | Timezone para containers. |
| `DUCKDNS_TOKEN`      | Token para validação DNS-01 (ACME DuckDNS). |
| `EMAIL`              | Email para registro ACME. |
| `MY_DOMAIN_DUCKDNS`  | Domínio base DuckDNS (`drake-ayu.duckdns.org`). |
| `MY_DOMAIN_LOCAL`    | Domínio local interno (`drake-ayu.local`). |
| `TS_AUTHKEY`         | Chave de autenticação Tailscale (opcional se login manual). |
| `REMOTE_DOCKER_HOST` | Usado internamente pelo Traefik (socket proxy). |
| `BASIC_AUTH`         | (Reservado) Para proteger serviços com Auth básica. |

Coloque um `.env` (não versionado) ao lado do compose.

---
## 🚀 Uso Rápido

1. Copie o modelo:
   ```bash
   cp .env.example .env
   # Edite DUCKDNS_TOKEN, TS_AUTHKEY etc.
   ```
2. (Opcional) Adapte domínios em `traefik.yml`, `traefik-dynamic.yml` e `Corefile`.
3. Garanta que a rede exista:
   ```bash
   docker network create proxy_net || true
   ```
4. Suba a stack:
   ```bash
   docker compose up -d
   ```
5. Verifique saúde:
   ```bash
   docker compose ps
   docker logs proxy-traefik --tail=50
   docker logs proxy-tailscale --tail=50
   ```
6. Teste o serviço exemplo:
   - `https://whoami.<MY_DOMAIN_DUCKDNS>`
   - `https://whoami.<MY_DOMAIN_LOCAL>` (se DNS local resolver)

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
| Cert não emite (ACME) | Verificar `DUCKDNS_TOKEN`; conferir logs Traefik (`level: DEBUG`). |
| whoami não resolve | Testar DNS local; verificar CoreDNS logs. |
| Tailscale unhealthy | `docker logs proxy-tailscale`; checar chave / políticas ACL. |
| Dashboard sem acesso | Confirmar domínio em `traefik-dynamic.yml` e DNS apontando. |
| Docker API exposta | Certifique-se que acesso só via tailnet; não exponha porta 2375 externamente. |

---
## 🔐 Segurança (Checklist)
- [ ] Rotacione `DUCKDNS_TOKEN` periodicamente.
- [ ] Use ACLs no painel Tailscale para limitar acesso.
- [ ] Considere remover permissões desnecessárias no `docker-socket-proxy` (variáveis que não usa).
- [ ] Não exponha portas host (usa tailnet + network_mode compartilhado).
- [ ] Proteja o dashboard Traefik com auth/middlewares se exposto além da tailnet.
- [ ] Revise `acme.json` permissões (`600` ideal) se for lidar manualmente.

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
- Middleware de autenticação central (Basic / ForwardAuth)
- Integração com Grafana / Loki para observabilidade
- Adicionar Healthcheck ao CoreDNS
- Templates para serviços TCP (ex.: MongoDB via SNI)
- Script de bootstrap para validação de dependências

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
