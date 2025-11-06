#!/bin/bash
# Bootstrap script for homelab-proxy-tailscale-coredns-traefik V2
# This script validates dependencies and prepares the environment

set -e

echo "================================================"
echo "  Homelab Proxy Bootstrap Script - V2"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    echo -e "${GREEN}✓${NC} Docker $DOCKER_VERSION"
else
    echo -e "${RED}✗${NC} Docker not found"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check Docker Compose
echo -n "Checking Docker Compose... "
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    echo -e "${GREEN}✓${NC} Docker Compose $COMPOSE_VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose not found"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check if Docker daemon is running
echo -n "Checking Docker daemon... "
if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Running"
else
    echo -e "${RED}✗${NC} Not running"
    echo "Please start Docker daemon"
    exit 1
fi

# Check network
echo -n "Checking proxy_net network... "
if docker network inspect proxy_net &> /dev/null; then
    echo -e "${GREEN}✓${NC} Exists"
else
    echo -e "${YELLOW}!${NC} Not found, creating..."
    docker network create proxy_net
    echo -e "${GREEN}✓${NC} Created"
fi

# Check .env file
echo -n "Checking .env file... "
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} Exists"
else
    echo -e "${YELLOW}!${NC} Not found, creating from .env.example..."
    cp .env.example .env
    echo -e "${GREEN}✓${NC} Created"
    echo -e "${YELLOW}⚠${NC}  Please edit .env with your credentials!"
fi

# Create required directories
echo -n "Creating required directories... "
mkdir -p letsencrypt logs certs tailscale/data acme haproxy
echo -e "${GREEN}✓${NC}"

# Set permissions on acme.json
echo -n "Setting permissions on acme.json... "
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
echo -e "${GREEN}✓${NC}"

# Check for required variables in .env
echo ""
echo "Checking .env configuration..."
REQUIRED_VARS=("DUCKDNS_TOKEN" "EMAIL" "MY_DOMAIN_DUCKDNS")
MISSING_VARS=()

for VAR in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^${VAR}=.\+" .env 2>/dev/null; then
        MISSING_VARS+=("$VAR")
    fi
done

if [ ${#MISSING_VARS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓${NC} All required variables are set"
else
    echo -e "${YELLOW}⚠${NC}  Missing or empty variables:"
    for VAR in "${MISSING_VARS[@]}"; do
        echo "   - $VAR"
    done
    echo ""
    echo "Please edit .env and set these variables"
fi

echo ""
echo "================================================"
echo -e "${GREEN}Bootstrap complete!${NC}"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Edit .env if needed (especially DUCKDNS_TOKEN and TS_AUTHKEY)"
echo "  2. Start services: make up"
echo "  3. Or use profiles: make up PROFILES='core dns demo'"
echo ""
echo "Available profiles:"
echo "  - core:     Tailscale + Traefik (minimal)"
echo "  - dns:      Add CoreDNS"
echo "  - demo:     Add whoami demo service"
echo "  - acme-ext: External ACME container"
echo "  - tools:    Docker API exposure (use carefully!)"
echo ""
