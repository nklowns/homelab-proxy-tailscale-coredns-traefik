#!/bin/bash
# Validation script for homelab-proxy-tailscale-coredns-traefik V2
# Checks configuration and service health

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "  Configuration Validation & Health Checks"
echo "================================================"
echo ""

ERRORS=0
WARNINGS=0

# Function to check if a service is running
check_service() {
    local SERVICE_NAME=$1
    echo -n "Checking $SERVICE_NAME... "
    
    if docker ps --format '{{.Names}}' | grep -q "^${SERVICE_NAME}$"; then
        STATUS=$(docker inspect --format='{{.State.Status}}' "$SERVICE_NAME" 2>/dev/null)
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$SERVICE_NAME" 2>/dev/null || echo "none")
        
        if [ "$STATUS" = "running" ]; then
            if [ "$HEALTH" = "healthy" ]; then
                echo -e "${GREEN}✓${NC} Running (healthy)"
            elif [ "$HEALTH" = "unhealthy" ]; then
                echo -e "${YELLOW}!${NC} Running (unhealthy)"
                ((WARNINGS++))
            elif [ "$HEALTH" = "starting" ]; then
                echo -e "${BLUE}⋯${NC} Running (starting)"
            else
                echo -e "${GREEN}✓${NC} Running"
            fi
        else
            echo -e "${RED}✗${NC} Not running (status: $STATUS)"
            ((ERRORS++))
        fi
    else
        echo -e "${YELLOW}○${NC} Not started"
    fi
}

# Check services
echo "Service Status:"
check_service "proxy-tailscale"
check_service "proxy-traefik"
check_service "proxy-coredns"
check_service "docker-socket-proxy"
check_service "whoami"

echo ""

# Check files and permissions
echo "File Checks:"

echo -n "Checking .env... "
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} Not found"
    ((ERRORS++))
fi

echo -n "Checking traefik.yml... "
if [ -f traefik.yml ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} Not found"
    ((ERRORS++))
fi

echo -n "Checking Corefile... "
if [ -f Corefile ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} Not found"
    ((ERRORS++))
fi

echo -n "Checking acme.json permissions... "
if [ -f letsencrypt/acme.json ]; then
    # Cross-platform stat command
    if stat --version 2>/dev/null | grep -q 'GNU'; then
        # Linux (GNU stat)
        PERMS=$(stat -c '%a' letsencrypt/acme.json)
    else
        # macOS/BSD (BSD stat)
        PERMS=$(stat -f '%A' letsencrypt/acme.json)
    fi
    if [ "$PERMS" = "600" ]; then
        echo -e "${GREEN}✓${NC} (600)"
    else
        echo -e "${YELLOW}!${NC} Wrong permissions ($PERMS, should be 600)"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}!${NC} Not found"
fi

echo ""

# Network checks
echo "Network Checks:"
echo -n "Checking proxy_net... "
if docker network inspect proxy_net &> /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC} Not found"
    ((ERRORS++))
fi

echo ""

# Service-specific checks
if docker ps --format '{{.Names}}' | grep -q "^proxy-tailscale$"; then
    echo "Tailscale Status:"
    docker exec proxy-tailscale tailscale status 2>/dev/null || echo -e "${YELLOW}⚠${NC} Could not get status"
    echo ""
fi

if docker ps --format '{{.Names}}' | grep -q "^proxy-traefik$"; then
    echo "Traefik Routers:"
    echo -n "Checking API endpoint... "
    if docker exec proxy-traefik wget -q -O /dev/null http://localhost:8080/api/http/routers 2>/dev/null; then
        ROUTER_COUNT=$(docker exec proxy-traefik wget -q -O - http://localhost:8080/api/http/routers 2>/dev/null | grep -o '"name"' | wc -l)
        echo -e "${GREEN}✓${NC} ($ROUTER_COUNT routers configured)"
    else
        echo -e "${YELLOW}!${NC} Could not access API"
        ((WARNINGS++))
    fi
    echo ""
fi

# Summary
echo "================================================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Checks completed with $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${RED}✗ Checks completed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    exit 1
fi
