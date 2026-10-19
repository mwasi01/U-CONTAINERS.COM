#!/usr/bin/env bash
# fix-repo.sh — one-shot repo restructuring for ngu-platform Pages deploy
# Run from repo root:  bash fix-repo.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "▶ Repo root: $(pwd)"

# =============================================================================
# 1. Move any leftover JPGs/AVIFs at root into public/assets/images/products/
#    Overwrite scaffold placeholders with -f
# =============================================================================
echo "▶ Moving leftover images…"
shopt -s nullglob
for f in *.jpg *.jpeg *.png *.avif *.webp; do
  [ -f "$f" ] || continue
  mv -f "$f" "public/assets/images/products/"
  echo "  moved: $f"
done
shopt -u nullglob

# =============================================================================
# 2. Move legacy HTML pages into public/ (so they don't override scaffold)
# =============================================================================
echo "▶ Moving legacy HTML pages…"
for page in index about services drumscontainers; do
  if [ -f "${page}.html" ]; then
    mv -f "${page}.html" "public/legacy-${page}.html"
    echo "  ${page}.html → public/legacy-${page}.html"
  fi
done

# =============================================================================
# 3. Move real product pages into public/products/ then drop root products/
# =============================================================================
if [ -d products ]; then
  echo "▶ Copying products/* into public/products/…"
  cp -rf products/. public/products/ 2>/dev/null || true
  rm -rf products
  echo "  removed root products/"
fi

# =============================================================================
# 4. Rename functions/assets → functions/media (stop intercepting /assets/*)
# =============================================================================
if [ -d functions/assets ]; then
  echo "▶ Renaming functions/assets → functions/media…"
  mv functions/assets functions/media
fi

# Force the R2 handler to use env.MEDIA (idempotent)
if [ -f "functions/media/[[path]].js" ]; then
  sed -i 's/env\.ASSETS/env.MEDIA/g' "functions/media/[[path]].js"
  echo "  patched functions/media/[[path]].js → env.MEDIA"
fi

# =============================================================================
# 5. Write wrangler.toml (Pages project)
# =============================================================================
echo "▶ Writing wrangler.toml…"
cat > wrangler.toml <<'EOF'
name = "ngu-platform"
compatibility_date = "2024-09-23"
compatibility_flags = ["nodejs_compat"]
pages_build_output_dir = "public"

[[d1_databases]]
binding = "DB"
database_name = "ngu-platform-db"
database_id = "b43b94eb-409f-476b-a1a1-6ca89b2e3797"

[[kv_namespaces]]
binding = "KV"
id = "1c57b00f009c43fdb1530a3a227e28fe"

[[r2_buckets]]
binding = "MEDIA"
bucket_name = "ngu-platform-assets"

[vars]
APP_ENV = "production"
EOF

# =============================================================================
# 6. Write package.json
# =============================================================================
echo "▶ Writing package.json…"
cat > package.json <<'EOF'
{
  "name": "ngu-platform",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "wrangler pages dev public",
    "deploy": "wrangler pages deploy public"
  },
  "devDependencies": { "wrangler": "^4.0.0" }
}
EOF

# =============================================================================
# 7. Write .gitignore
# =============================================================================
echo "▶ Writing .gitignore…"
cat > .gitignore <<'EOF'
node_modules/
.wrangler/
.dev.vars
.env
.env.*
!.env.example
*.log
.DS_Store
EOF

# =============================================================================
# 8. Sanity: verify src/ and functions/ structure
# =============================================================================
echo "▶ Sanity checks…"
test -d functions            || { echo "FATAL: functions/ missing"; exit 1; }
test -d functions/api        || { echo "FATAL: functions/api missing"; exit 1; }
test -d src                  || { echo "FATAL: src/ missing"; exit 1; }
test -d migrations           || { echo "FATAL: migrations/ missing"; exit 1; }
test -d public               || { echo "FATAL: public/ missing"; exit 1; }
test -f "public/index.html"  || { echo "FATAL: public/index.html missing"; exit 1; }
test -f "src/auth.js"        || { echo "FATAL: src/auth.js missing"; exit 1; }
test -f "functions/_middleware.js" || { echo "FATAL: functions/_middleware.js missing"; exit 1; }

echo ""
echo "✅ Structure check passed."
echo ""
echo "Root contents:"
ls -1
echo ""
echo "functions/ subdirs:"
ls -d functions/*/ 2>/dev/null
echo ""
echo "public/ top-level:"
ls -1 public | head -20
echo ""
echo "Product images:"
ls -1 public/assets/images/products | head -20
echo ""

# =============================================================================
# 9. Git config to suppress CRLF warnings
# =============================================================================
echo "▶ Configuring git to suppress CRLF warnings…"
git config --local core.autocrlf false
git config --local core.eol lf

# =============================================================================
# 10. Stage, commit, push
# =============================================================================
echo "▶ Staging changes…"
git add -A

echo ""
echo "▶ Files staged (summary):"
git status --short | head -40
echo "  ..."

echo ""
echo "▶ Committing…"
git -c user.name="$(git config user.name || echo 'st')" \
    -c user.email="$(git config user.email || echo 'st@localhost')" \
    commit -m "Restructure: Pages project with public/, functions/, src/" \
    || echo "  (nothing to commit — skipped)"

echo ""
echo "▶ Pushing to origin/main…"
git push origin main

echo ""
echo "✅ Done. Now:"
echo "   1. Cloudflare Dashboard → Workers & Pages → Create → Pages → Connect to Git"
echo "   2. Repo: mwasi01/U-CONTAINERS.COM, branch: main"
echo "   3. Build command: (empty)   Build output: public"
echo "   4. Settings → Functions → Bindings: DB, KV, MEDIA"
echo "   5. Settings → Environment variables → JWT_SECRET"
echo "   6. Settings → Custom domains → ngucontainers.com"
echo "   7. npx wrangler d1 migrations apply ngu-platform-db --remote"
echo "   8. npx wrangler d1 execute ngu-platform-db --remote --file=./migrations/0042_seed.sql"
