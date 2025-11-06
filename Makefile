# Makefile for homelab-proxy-tailscale-coredns-traefik
# V2 automation

.PHONY: help network acme-perms up down restart logs ps clean env-check bootstrap

# Default profiles to use
PROFILES ?= core dns

help: ## Show this help message
	@echo "homelab-proxy-tailscale-coredns-traefik - V2"
	@echo ""
	@echo "Usage: make [target] [PROFILES='profile1 profile2']"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Available profiles: core, dns, demo, acme-ext, tools"
	@echo "Default profiles: $(PROFILES)"

network: ## Create proxy_net network if it doesn't exist
	@echo "Creating proxy_net network..."
	@docker network create proxy_net 2>/dev/null || echo "Network proxy_net already exists"

acme-perms: ## Set correct permissions on letsencrypt/acme.json
	@echo "Setting permissions on letsencrypt/acme.json..."
	@mkdir -p letsencrypt
	@touch letsencrypt/acme.json
	@chmod 600 letsencrypt/acme.json
	@echo "✓ acme.json permissions set to 600"

env-check: ## Check if .env file exists
	@if [ ! -f .env ]; then \
		echo "⚠ .env file not found. Copying from .env.example..."; \
		cp .env.example .env; \
		echo "✓ .env created. Please edit it with your credentials."; \
		exit 1; \
	fi
	@echo "✓ .env file exists"

bootstrap: env-check network acme-perms ## Bootstrap the environment (run once)
	@echo "✓ Bootstrap complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit .env with your credentials (DUCKDNS_TOKEN, TS_AUTHKEY, etc.)"
	@echo "  2. Run: make up"

up: env-check network acme-perms ## Start services with specified profiles
	@echo "Starting services with profiles: $(PROFILES)..."
	@PROFILE_ARGS=""; \
	for profile in $(PROFILES); do \
		PROFILE_ARGS="$$PROFILE_ARGS --profile $$profile"; \
	done; \
	docker compose $$PROFILE_ARGS up -d

down: ## Stop all services
	@echo "Stopping all services..."
	@docker compose --profile core --profile dns --profile demo --profile acme-ext --profile tools down

restart: down up ## Restart services

logs: ## Follow logs from main services
	@docker compose logs -f proxy-tailscale proxy-traefik proxy-coredns

ps: ## Show running containers
	@docker compose ps -a

clean: down ## Stop services and remove volumes (CAREFUL!)
	@echo "⚠ This will remove all volumes. Press Ctrl+C to cancel, or wait 5 seconds..."
	@sleep 5
	@docker compose --profile core --profile dns --profile demo --profile acme-ext --profile tools down -v
	@echo "✓ All services stopped and volumes removed"

validate: ## Validate configuration files
	@echo "Validating docker-compose.yml..."
	@docker compose config > /dev/null && echo "✓ docker-compose.yml is valid" || echo "✗ docker-compose.yml has errors"

health: ## Check health of running services
	@echo "Service health status:"
	@docker compose ps --format "table {{.Name}}\t{{.Status}}"

# Profile-specific shortcuts
up-core: ## Start only core services (tailscale + traefik)
	@$(MAKE) up PROFILES="core"

up-full: ## Start all services (core + dns + demo)
	@$(MAKE) up PROFILES="core dns demo"

up-tools: ## Start with tools profile (includes Docker API exposure)
	@$(MAKE) up PROFILES="core dns tools"

# Development helpers
dev-logs: ## Tail logs with timestamps
	@docker compose logs -f --timestamps

shell-traefik: ## Open shell in Traefik container
	@docker exec -it proxy-traefik sh

shell-tailscale: ## Open shell in Tailscale container
	@docker exec -it proxy-tailscale sh

shell-coredns: ## Open shell in CoreDNS container
	@docker exec -it proxy-coredns sh

# Maintenance
update-images: ## Pull latest versions of pinned images
	@echo "Pulling images..."
	@docker compose pull

backup-certs: ## Backup certificates and Tailscale state
	@echo "Backing up certificates and state..."
	@mkdir -p backups
	@tar -czf backups/backup-$(shell date +%Y%m%d-%H%M%S).tar.gz letsencrypt/ tailscale/data/ certs/
	@echo "✓ Backup created in backups/"

# Testing
test-dns: ## Test CoreDNS resolution
	@echo "Testing DNS resolution..."
	@if [ -f .env ]; then \
		. ./.env && docker exec proxy-coredns dig @127.0.0.1 whoami.$$MY_DOMAIN_DUCKDNS A; \
	else \
		docker exec proxy-coredns dig @127.0.0.1 whoami.drake-ayu.duckdns.org A; \
	fi
