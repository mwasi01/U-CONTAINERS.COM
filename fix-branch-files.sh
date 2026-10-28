#!/usr/bin/env bash
# fix-branch-files.sh — replace all remaining Nakuru references + fix phone numbers
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

# =============================================================================
# 1. Rename nakuru.html → wangige.html (if not already done)
# =============================================================================
if [ -f public/branches/nakuru.html ] && [ ! -f public/branches/wangige.html ]; then
  echo "▶ Renaming nakuru.html → wangige.html"
  git mv public/branches/nakuru.html public/branches/wangige.html 2>/dev/null \
    || mv public/branches/nakuru.html public/branches/wangige.html
fi

# If both exist (previous partial run), remove the old one
if [ -f public/branches/nakuru.html ] && [ -f public/branches/wangige.html ]; then
  echo "▶ Both nakuru.html and wangige.html exist — deleting nakuru.html"
  rm -f public/branches/nakuru.html
fi

# =============================================================================
# 2. Replace Nakuru → Wangige in every HTML file (skip legacy)
# =============================================================================
echo "▶ Replacing Nakuru → Wangige across all HTML files"

find public -type f -name "*.html" ! -name "legacy-*" ! -name "legacy_*" | while IFS= read -r file; do
  # Skip if the file doesn't contain "akuru" or "kuru" anywhere
  if ! grep -qi "nakuru" "$file" && ! grep -q "Nakuru" "$file"; then
    continue
  fi
  # Case-sensitive replacements first (to preserve context)
  sed -i 's/Nakuru Branch/Wangige Branch/g' "$file"
  sed -i 's/Nakuru/Wangige/g' "$file"
  sed -i 's/nakuru/wangige/g' "$file"
  echo "  ✓ $file"
done

# Also update any JS files
find public -type f -name "*.js" | while IFS= read -r file; do
  if grep -qi "nakuru" "$file"; then
    sed -i 's/Nakuru/Wangige/g; s/nakuru/wangige/g' "$file"
    echo "  ✓ $file"
  fi
done

# =============================================================================
# 3. Fix Kikuyu branch phone number (0708 608 440)
# =============================================================================
echo "▶ Updating Kikuyu branch phone to +254 708 608 440"

# Only in the Kikuyu branch page
sed -i 's|tel:+254704787011|tel:+254708608440|g' public/branches/kikuyu.html
sed -i 's|+254 704 787 011|+254 708 608 440|g' public/branches/kikuyu.html
sed -i 's|254 704 787 011|254 708 608 440|g' public/branches/kikuyu.html
sed -i 's|0708 608 440|0708 608 440|g' public/branches/kikuyu.html

# Update the branches index — but only the Kikuyu card, not the whole file
# (index has both Kikuyu and Wangige cards; Kikuyu phone shows first)
# Easier: replace the first occurrence only per file
awk '
  BEGIN { replaced = 0 }
  {
    if (!replaced && ($0 ~ /tel:\+254704787011|254 704 787 011/)) {
      gsub(/tel:\+254704787011/, "tel:+254708608440")
      gsub(/\+254 704 787 011/, "+254 708 608 440")
      gsub(/254 704 787 011/, "254 708 608 440")
      replaced = 1
    }
    print
  }
' public/branches/index.html > public/branches/index.html.tmp && \
  mv public/branches/index.html.tmp public/branches/index.html

# =============================================================================
# 4. Verify the fix
# =============================================================================
echo ""
echo "▶ Verification:"
echo ""
echo "--- branches/index.html — should say Wangige, not Nakuru ---"
grep -E "Kikuyu Branch|Wangige Branch|Nakuru Branch" public/branches/index.html || echo "(none found)"
echo ""
echo "--- branches/index.html — links should be /branches/wangige.html ---"
grep -E "href=\"/branches/(kikuyu|wangige|nakuru)\.html\"" public/branches/index.html || echo "(none found)"
echo ""
echo "--- Kikuyu page — phone should be +254 708 608 440 ---"
grep -E "708 608 440|704 787 011" public/branches/kikuyu.html || echo "(none found)"
echo ""
echo "--- Wangige page — should exist, should say Wangige ---"
if [ -f public/branches/wangige.html ]; then
  grep -E "Wangige Branch|Nakuru" public/branches/wangige.html | head -3
else
  echo "ERROR: wangige.html missing!"
fi
echo ""

# =============================================================================
# 5. Also replace Nakuru in the JS files that reference product images
# =============================================================================
if [ -f public/assets/js/product-images.js ]; then
  sed -i 's|/assets/images/branches/nakuru.jpg|/assets/images/branches/wangige.jpg|g' public/assets/js/product-images.js
fi

# =============================================================================
# 6. Stage
# =============================================================================
echo "▶ Staging files…"
git add public/ 2>/dev/null || true

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Branch file fixes applied."
echo ""
echo "Next:"
echo "  npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  git add -A; git commit -m 'fix: rename Nakuru→Wangige in HTML files + Kikuyu phone'; git push origin main"
echo ""
