# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-06

### Added
- **Docker Compose Profiles**: Introduzido sistema de profiles para controlar quais serviços iniciar
  - `core`: Serviços essenciais (Tailscale + Traefik + Docker Socket Proxy)
  - `dns`: Adiciona CoreDNS
  - `demo`: Adiciona serviço de exemplo (whoami)
  - `tools`: Habilita exposição da Docker API (usar com cuidado!)
  - `acme-ext`: Container ACME externo
- **Image Pinning**: Versões de imagens Docker agora são fixadas via variáveis em `.env`
  - `TRAEFIK_IMAGE` (default: traefik:v3.1)
  - `COREDNS_IMAGE` (default: coredns/coredns:1.11.1)
  - `TAILSCALE_IMAGE` (default: tailscale/tailscale:v1.74.0)
- **Makefile**: Automação completa para operações comuns
  - `make bootstrap`: Configura ambiente inicial
  - `make up/down`: Gerencia serviços
  - `make logs`, `make health`: Monitoramento
  - `make shell-*`: Acesso rápido aos containers
- **Scripts de Automação**:
  - `scripts/bootstrap.sh`: Valida dependências e prepara ambiente
  - `scripts/checks.sh`: Verifica saúde e configuração do sistema
- **Healthchecks**: Todos os serviços principais agora têm healthchecks configurados
  - Traefik: healthcheck via ping endpoint
  - CoreDNS: validação via dig
  - Tailscale: status check
- **Configuração de Log**: Log level do Traefik agora é configurável via `TRAEFIK_LOG_LEVEL`
- **Documentação V2**: README.md completamente reescrito com foco em V2

### Changed
- **BREAKING**: Docker API não é mais exposta por padrão
  - Movida para um serviço separado (`docker-api-exposure`) ativado apenas com profile `tools`
  - Aumenta significativamente a segurança
- **Docker Socket Proxy**: Permissões reduzidas para o mínimo necessário
  - Apenas `CONTAINERS`, `NETWORKS`, `SERVICES`, `TASKS` habilitados por padrão
  - Permissões perigosas (`AUTH`, `SECRETS`, `POST`) desabilitadas
- **Variáveis de Ambiente**: `.env.example` expandido com novas variáveis
  - Variáveis de versão de imagem
  - Configurações de ACME (staging/production)
  - Tailnet hostname e IPv4 hint
  - Configurações de log e métricas

### Security
- ✅ Docker Socket Proxy com permissões mínimas
- ✅ Docker API não exposta por padrão (requer profile `tools`)
- ✅ `acme.json` automaticamente configurado com permissões 600
- ✅ Versões de imagens fixadas (evita surpresas de `:latest`)
- ✅ `.gitignore` melhorado para prevenir commit de arquivos sensíveis

### Improved
- **ROADMAP.md**: Atualizado com status de conclusão do MVP V2.0.0
- **.gitignore**: Expandido para cobrir mais casos (backups, múltiplos .env, etc.)
- **Segurança**: Documentação expandida sobre práticas de segurança

### Documentation
- Guia de início rápido reescrito com foco em automação via Makefile
- Seção de troubleshooting expandida
- Tabela completa de variáveis de ambiente
- Documentação de profiles e casos de uso
- Guia de segurança com práticas recomendadas

## [1.0.0] - 2024-XX-XX

### Added
- Configuração inicial do projeto
- Stack Traefik + Tailscale + CoreDNS
- Suporte a DuckDNS para DNS-01 challenge
- Certificados Tailscale via tailsolver
- Docker Socket Proxy para segurança básica
- Configuração de exemplo com whoami
- README e documentação inicial
- ACME externo opcional via acme.sh

[2.0.0]: https://github.com/nklowns/homelab-proxy-tailscale-coredns-traefik/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/nklowns/homelab-proxy-tailscale-coredns-traefik/releases/tag/v1.0.0
