#!/usr/bin/env bash
# deploy-to-prod.sh — apply migrations + seed production D1, verify live
# Run from repo root: bash deploy-to-prod.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "▶ Repo root: $(pwd)"
echo ""

# -----------------------------------------------------------------------------
# Preconditions
# -----------------------------------------------------------------------------
test -f wrangler.toml || { echo "FATAL: wrangler.toml not found"; exit 1; }
test -d migrations    || { echo "FATAL: migrations/ not found"; exit 1; }
test -f migrations/0042_seed.sql || { echo "FATAL: migrations/0042_seed.sql not found"; exit 1; }

# Verify wrangler is available
if ! command -v npx >/dev/null 2>&1; then
  echo "FATAL: npx not found. Install Node first."
  exit 1
fi

echo "▶ Checking wrangler login…"
if ! npx wrangler whoami >/dev/null 2>&1; then
  echo "Not logged in. Running: npx wrangler login"
  npx wrangler login
fi

npx wrangler whoami | head -3
echo ""

# -----------------------------------------------------------------------------
# 1. Apply migrations to REMOTE D1
# -----------------------------------------------------------------------------
echo "▶ Applying migrations to REMOTE D1: ngu-platform-db"
echo "  (This may prompt for confirmation — answer Y)"
echo ""
npx wrangler d1 migrations apply ngu-platform-db --remote

echo ""
echo "✔ Migrations applied."
echo ""

# -----------------------------------------------------------------------------
# 2. Seed REMOTE D1
# -----------------------------------------------------------------------------
echo "▶ Seeding REMOTE D1 from migrations/0042_seed.sql"
echo ""
npx wrangler d1 execute ngu-platform-db --remote --file=./migrations/0042_seed.sql

echo ""
echo "✔ Seed applied."
echo ""

# -----------------------------------------------------------------------------
# 3. Verify seeded rows
# -----------------------------------------------------------------------------
echo "▶ Verifying seeded branches:"
npx wrangler d1 execute ngu-platform-db --remote \
  --command "SELECT id, name, slug FROM branches;" \
  2>&1 | tee /tmp/ngu-branches.txt

echo ""
echo "▶ Verifying seeded categories:"
npx wrangler d1 execute ngu-platform-db --remote \
  --command "SELECT slug, name FROM categories;" \
  2>&1 | tee /tmp/ngu-categories.txt

echo ""

# -----------------------------------------------------------------------------
# 4. Verify live API (if domain resolves)
# -----------------------------------------------------------------------------
echo "▶ Checking live API on ngucontainers.com…"

check_url() {
  local url="$1"
  local label="$2"
  echo ""
  echo "  ▶ $label"
  echo "    $url"
  if command -v curl >/dev/null 2>&1; then
    local out
    out=$(curl -sS -m 15 -w "\n  HTTP:%{http_code}" "$url" 2>&1 || true)
    echo "    $out"
  else
    echo "    (curl not available — skipping)"
  fi
}

check_url "https://ngucontainers.com/api/health"          "GET /api/health"
check_url "https://ngucontainers.com/api/org/branches"    "GET /api/org/branches"

echo ""
echo "▶ Checking static assets…"
check_url "https://ngucontainers.com/assets/css/styles.css" "GET /assets/css/styles.css (should be 200, not 404)"
check_url "https://ngucontainers.com/"                       "GET / (should be 200, styled)"

echo ""

# -----------------------------------------------------------------------------
# 5. If API doesn't respond, print debug hints
# -----------------------------------------------------------------------------
if command -v curl >/dev/null 2>&1; then
  HEALTH=$(curl -sS -m 10 -o /dev/null -w "%{http_code}" https://ngucontainers.com/api/health 2>/dev/null || echo "000")
  if [ "$HEALTH" != "200" ]; then
    echo "⚠ /api/health returned HTTP $HEALTH — this is not OK yet."
    echo ""
    echo "  Most likely causes:"
    echo "    1. Bindings not added to the Pages project yet"
    echo "         → Dashboard → Pages project → Settings → Functions → Bindings"
    echo "         → Add DB (D1), KV (namespace), MEDIA (R2 bucket)"
    echo "    2. JWT_SECRET env var not set"
    echo "         → Dashboard → Pages project → Settings → Environment variables"
    echo "    3. Bindings added but no redeploy"
    echo "         → Dashboard → Deployments → Retry deployment"
    echo "    4. Custom domain not attached to the Pages project"
    echo "         → Dashboard → Pages project → Custom domains → Add ngucontainers.com"
    echo "    5. Old Worker still owns the domain route"
    echo "         → Dashboard → Workers & Pages → u-containers-com (Worker, not Pages)"
    echo "         → Settings → Delete"
    echo ""
  else
    echo "✅ /api/health returned 200 — backend is live."
  fi
fi

echo ""
echo "✅ CLI steps complete."
echo ""
echo "Remaining manual dashboard steps (if not already done):"
echo "  1. Pages project → Settings → Functions → Bindings: DB, KV, MEDIA"
echo "  2. Pages project → Settings → Environment variables: JWT_SECRET"
echo "  3. Pages project → Deployments → Retry deployment (after bindings)"
echo "  4. Pages project → Custom domains → ngucontainers.com"
echo "  5. Delete old Worker 'u-containers-com' to free the domain"
echo ""
