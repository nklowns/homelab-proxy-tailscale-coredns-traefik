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
| `Makefile`                        | Ponto de entrada para automação (bootstrap, renderização, start/stop). |
| `docker-compose.yml`              | Orquestra todos os serviços. |
| `config/`                         | Contém os templates (`.tmpl`) para `gomplate`. |
| `config/traefik.yml.tmpl`         | Template para a configuração estática do Traefik. |
| `config/traefik-dynamic.yml.tmpl` | Template para a configuração dinâmica (routers, middlewares). |
| `config/Corefile.tmpl`            | Template para as regras do CoreDNS. |
| `traefik.yml`                     | **Gerado** pelo `make`. Configuração estática do Traefik. |
| `traefik-dynamic.yml`             | **Gerado** pelo `make`. Configuração dinâmica. |
| `Corefile`                        | **Gerado** pelo `make`. Regras do CoreDNS. |
| `certs/`                          | Certificados locais (ex.: `drake-ayu.local.*`). |
| `letsencrypt/`                    | Armazena `acme.json` (persistência ACME). |
| `logs/`                           | Logs de acesso (`access.log`). |
| `acme/`                           | Dockerfile + script para emissão manual/externa (opcional). |
| `tailscale/`                      | Estado e socket do Tailscale (`data/`, `tailscaled.sock`). |
| `.env.example`                    | Variáveis de ambiente modelo. |
| `.env`                            | **Seu arquivo local** de variáveis (ignorado pelo git). |

---
## ✅ Requisitos

- Docker + Docker Compose
- `make` para executar os comandos de automação.
- Conta DuckDNS (token)
- Conta Tailscale (auth key se usar key-based auth)

---
## 🔐 Variáveis de Ambiente (`.env`)
Baseado em `.env.example`. Crie um arquivo `.env` com suas configurações.

| Variável | Função |
|----------|--------|
| `TZ`                             | Timezone para containers. |
| `TRAEFIK_IMAGE`...`WHOAMI_IMAGE` | Versões das imagens Docker a serem usadas. |
| `TRAEFIK_LOG_LEVEL`              | Nível de log do Traefik (e.g., `INFO`, `DEBUG`). |
| `TRAEFIK_METRICS_ENABLED`        | *(Não implementado)* Reservado para ativar/desativar o endpoint de métricas do Prometheus. |
| `DUCKDNS_TOKEN`                  | Token para validação DNS-01 (ACME DuckDNS). |
| `ACME_EMAIL`                     | Email para registro e notificações da ACME (Let's Encrypt/ZeroSSL). |
| `ACME_CA_SERVER`                 | Servidor ACME a ser usado. Use `staging` para testes e `production` para produção. |
| `DOMAIN_DUCKDNS`                 | Domínio base DuckDNS (ex: `drake-ayu.duckdns.org`). |
| `DOMAIN_LOCAL`                   | Domínio local interno (ex: `drake-ayu.local`). |
| `DOMAIN_TSNET`                   | Domínio Tailscale MagicDNS (ex: `drake-ayu.ts.net`). |
| `TS_AUTHKEY`                     | Chave de autenticação Tailscale para provisionamento automático. |
| `TAILNET_HOSTNAME`               | Nome do host que o proxy terá na rede Tailscale. |
| `TAILNET_IPV4_HINT`              | O IP da sua máquina na rede Tailscale. Usado pelo CoreDNS. |
| `REMOTE_DOCKER_HOST`             | Usado internamente pelo Traefik (socket proxy). |

Coloque um `.env` (não versionado) ao lado do compose.

---
## 🚀 Uso Rápido

O `Makefile` automatiza todo o processo de setup e execução.

1.  **Bootstrap (executar apenas uma vez):**
    Este comando irá criar o arquivo `.env` a partir do exemplo, a rede `proxy_net` e ajustar permissões de arquivos necessários.
    ```bash
    make bootstrap
    ```
2.  **Edite suas credenciais:**
    Abra o arquivo `.env` recém-criado e preencha no mínimo `DUCKDNS_TOKEN`, `TS_AUTHKEY`, `ACME_EMAIL` e seus domínios.

3.  **Suba a stack:**
    Este comando irá validar as variáveis, renderizar os arquivos de configuração a partir dos templates e iniciar todos os serviços.
    ```bash
    make up
    ```
4.  **Verifique a saúde dos serviços:**
    Para ver logs de um serviço específico (ex: `proxy-traefik`):
    ```bash
    docker compose logs -f proxy-traefik
    ```

5.  **Teste os serviços de exemplo:**
    - `https://whoami.your-domain.duckdns.org`
    - `https://whoami.your-domain.local` (se seu DNS local resolver)
    - `https://traefik.your-domain.duckdns.org` (para o dashboard do Traefik)

### Comandos úteis do Makefile
- `make up`: Inicia os containers.
- `make down`: Para todos os containers.
- `make restart`: Reinicia a stack.
- `make render-config`: Força a renderização dos templates de configuração.
- `make validate-vars`: Checa se as variáveis essenciais estão definidas no `.env`.

---
## 🌐 Traefik
### EntryPoints
- `web` (80) redireciona para `websecure` (HTTPS).
- `websecure` (443) ponto de entrada principal para tráfego HTTPS.
- `docker-tcp` (2375) expõe Docker API via TCP (controlado por labels) — protegido pela tailnet
- `mongodb-tcp` (27017) placeholder para serviços TCP futuros

### Providers
- **Docker**: via `docker-socket-proxy` para descobrir containers na rede `proxy_net` de forma segura.
- **File**: aponta para `traefik-dynamic.yml` (gerado), que contém routers e middlewares.

### Certificados
- `leresolverDuckdns`: Resolvedor ACME que usa o método DNS-01 com DuckDNS.
- `tailsolver`: Resolvedor que obtém certificados TLS diretamente da sua tailnet.
- **Certificados Locais**: Para o `DOMAIN_LOCAL`, certificados são lidos do diretório `/certs`.

---
## 🔒 Tailscale
- `proxy-tailscale` roda `tailscaled` e compartilha seu namespace de rede com Traefik e CoreDNS (`network_mode: service:proxy-tailscale`). Isso garante que todos usem o mesmo IP da Tailscale.
- **Benefícios**: IP estável na tailnet, certificados TLS via `tailsolver`, ACLs de segurança e MagicDNS.
- O estado do Tailscale é persistido no volume `tailscale/data`.

Se não usar `TS_AUTHKEY`, você precisará autenticar manualmente:
```bash
docker exec -it proxy-tailscale tailscale up
```

---
## 🧾 CoreDNS
O `Corefile` (gerado a partir do `config/Corefile.tmpl`) responde para seus domínios (`DOMAIN_DUCKDNS`, `DOMAIN_LOCAL`, `DOMAIN_TSNET`).

Ele usa o plugin `template` para gerar dinamicamente registros A, AAAA, HTTPS e SVCB, apontando para o IP da sua máquina na Tailnet (`TAILNET_IPV4_HINT`).

Para testar o DNS de dentro da stack:
```bash
docker exec -it proxy-coredns dig @127.0.0.1 whoami.drake-ayu.duckdns.org A
```

---
## 🔑 ACME / Certificados
### Via Traefik (principal)
- **DNS-01 DuckDNS**: Requer `DUCKDNS_TOKEN` e `ACME_EMAIL` no `.env`.
- **Armazenamento**: O `acme.json` é criado e gerenciado pelo Traefik no volume `letsencrypt/`. As permissões são ajustadas automaticamente pelo `make bootstrap`.

### Via Container ACME externo (opcional)
- O diretório `acme/` contém um `Dockerfile` e `entrypoint.sh` que usam `acme.sh`.
- Este serviço (`acme-duckdns`) está comentado no `docker-compose.yml` e pode ser usado para debug ou cenários específicos.

---
## ➕ Adicionando um Novo Serviço
No novo container (mesma rede `proxy_net`):
```yaml
labels:
  - traefik.enable=true
  - traefik.http.services.meuapp.loadbalancer.server.port=8080
  - traefik.http.routers.meuapp.rule=Host(`meuapp.${DOMAIN_DUCKDNS}`) || Host(`meuapp.${DOMAIN_LOCAL}`)
  - traefik.http.routers.meuapp.entrypoints=websecure
```
Se precisar de middleware (auth básica, headers, rate limit), adicione em `traefik-dynamic.yml` ou via labels.

---
## 🛠 Troubleshooting

| Sintoma | Ação |
|---------|------|
| Containers não sobem | Verifique se executou `make bootstrap` e configurou o `.env` |
| Erro "proxy_net network not found" | Execute `make network` ou `docker network create proxy_net` |
| Erro de permissões no `acme.json` | Execute `make file-perms` para corrigir |
| Traefik não emite certificados | Verifique se `DUCKDNS_TOKEN` está correto no `.env` |
| CoreDNS não resolve domínios | Verifique se `TAILNET_IPV4_HINT` está correto (IP da máquina na tailnet) |
| Tailscale não conecta | Execute `docker exec -it proxy-tailscale tailscale up` se não usar `TS_AUTHKEY` |
| Erro ao renderizar configs | Verifique se todas as variáveis obrigatórias estão no `.env` (use `make validate-vars`) |
| Dashboard do Traefik não acessível | Verifique se o domínio está resolvendo corretamente e se os certificados foram emitidos |

---
## 🔐 Segurança (Checklist)
- [ ] Rotacione `DUCKDNS_TOKEN` e `TS_AUTHKEY` periodicamente.
- [ ] Use ACLs no painel da Tailscale para restringir o acesso entre máquinas na sua tailnet.
- [ ] Revise as permissões do `docker-socket-proxy` no `docker-compose.yml` para garantir que apenas o necessário está exposto.
- [ ] Não exponha portas do host na internet. Deixe que a Tailscale gerencie o acesso.
- [ ] Proteja o dashboard do Traefik com um middleware de autenticação (ex: `forwardAuth` ou `basicAuth`) se houver chance de exposição.

---
## 🧪 Testes Rápidos
```bash
# Ver routers carregados via API do Traefik (requer DNS local ou túnel)
curl -s --cacert certs/drake-ayu.local.crt https://traefik.drake-ayu.local/api/http/routers | jq 'keys'

# Checar certificados armazenados no volume
docker exec -it proxy-traefik ls -l /letsencrypt
```

---
## 🗺 Roadmap / Ideias Futuras
- [ ] Middleware de autenticação central (ex: Authelia, via `forwardAuth`).
- [ ] Integração com Grafana / Loki para observabilidade avançada (usando as métricas do Traefik).
- [ ] Adicionar mais templates para serviços TCP (ex.: PostgreSQL, Redis).
- [ ] Criar perfis no `docker-compose.yml` para habilitar/desabilitar grupos de serviços (ex: `observability`, `database`).

---
## 🙌 Contribuição
PRs e sugestões são bem-vindos. Abra uma issue com ideias ou problemas.

---
## 📎 Notas
- O IP da Tailnet (`TAILNET_IPV4_HINT`) no `.env` é crucial para o CoreDNS funcionar corretamente.
- Toda a configuração é agora gerenciada por templates. Edite os arquivos `.tmpl` em `config/`, não os arquivos na raiz.

---
## ✨ Resumo
Este repositório fornece um ponto de partida sólido e automatizado para expor serviços internos com segurança através de Traefik + Tailscale. Ele resolve nomes e certificados automaticamente, mantendo a superfície de ataque mínima e simplificando a gestão com `make` e `gomplate`.
