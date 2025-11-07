.PHONY: bootstrap env-check network file-perms up down restart render-config validate-vars pull-gomplate

bootstrap: env-check network file-perms ## Bootstrap the environment (run once)
	@echo "Bootstrap complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit .env with your credentials (DUCKDNS_TOKEN, TS_AUTHKEY, etc.)"
	@echo "  2. Run: make up"

env-check: ## Check if .env file exists
	@echo "Creating .env file..."
	@if [ ! -f .env ]; then \
		echo "⚠ .env file not found. Copying from .env.example..."; \
		cp .env.example .env; \
		echo "Please edit it with your credentials."; \
		exit 1; \
	fi
	@echo "✓ .env file exists"

network: ## Create proxy_net network if it doesn't exist
	@echo "Creating proxy_net network..."
	@docker network create proxy_net 2>/dev/null || echo "✓ Network proxy_net exists"

file-perms: acme-perms logs-perms ## Set correct file permissions

acme-perms: ## Set correct permissions on letsencrypt/acme.json
	@echo "Setting permissions on letsencrypt/acme.json..."
	@mkdir -p letsencrypt
	@touch letsencrypt/acme.json
	@chmod 600 letsencrypt/acme.json
	@echo "✓ letsencrypt/acme.json exists"

logs-perms: ## Set correct permissions on logs/access.log
	@echo "Setting permissions on logs/access.log..."
	@mkdir -p logs
	@touch logs/access.log
	@chmod 600 logs/access.log
	@echo "✓ logs/access.log exists"

### Docker

up: env-check network file-perms ## Start services
	$(MAKE) render-config
	@docker compose up -d

down: ## Stop all services
	@echo "Stopping all services..."
	@docker compose down

restart: down up ## Restart services

GOMPLATE_IMAGE ?= hairyhenderson/gomplate:stable

pull-gomplate:
	@docker pull $(GOMPLATE_IMAGE) >/dev/null
	@echo "✓ gomplate image ready: $(GOMPLATE_IMAGE)"

validate-vars: ## Validar variáveis essenciais no .env
	@echo "Validating required variables in .env..."
	@missing=0; \
	for v in ACME_EMAIL DOMAIN_DUCKDNS DOMAIN_LOCAL DOMAIN_TSNET TAILNET_IPV4_HINT; do \
		val=$$(grep -E "^$$v=" .env | cut -d= -f2); \
		if [ -z "$$val" ]; then \
			echo "✗ $$v está vazio"; \
			missing=1; \
		else \
			echo "✓ $$v definido"; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo "⚠ Preencha as variáveis acima antes de subir."; \
		exit 1; \
	else \
		echo "All required variables are set."; \
	fi

render-config: env-check validate-vars pull-gomplate ## Render configs via gomplate container (usa --env-file .env)
	@echo "Rendering configuration with gomplate (container, --env-file .env)..."
	@docker run --rm \
		--env-file .env \
		-v $$PWD:/work \
		-w /work \
		$(GOMPLATE_IMAGE) \
		-f config/traefik.yml.tmpl \
		-o traefik.yml
	@docker run --rm \
		--env-file .env \
		-v $$PWD:/work \
		-w /work \
		$(GOMPLATE_IMAGE) \
		-f config/traefik-dynamic.yml.tmpl \
		-o traefik-dynamic.yml
	@docker run --rm \
		--env-file .env \
		-v $$PWD:/work \
		-w /work \
		$(GOMPLATE_IMAGE) \
		-f config/Corefile.tmpl \
		-o Corefile
	@echo "✓ Rendered Corefile, traefik.yml and traefik-dynamic.yml"
