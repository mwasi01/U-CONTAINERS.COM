#!/usr/bin/env bash
# rename-branch.sh — rename Nakuru branch to Wangige everywhere
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

# =============================================================================
# 1. Migration — rename branch in DB + update stock rows
# =============================================================================
echo "▶ Writing migrations/0048_rename_nakuru_to_wangige.sql"
cat > migrations/0048_rename_nakuru_to_wangige.sql <<'SQL'
-- 0048_rename_nakuru_to_wangige.sql
-- The business owner renamed the second branch from "Nakuru" to "Wangige".
-- This updates the branch row, its slug, and any stock rows already tied to it.

-- Update the branch itself (safe even if already renamed)
UPDATE branches
SET
  id = CASE WHEN id = 'br_nakuru' THEN 'br_wangige' ELSE id END,
  name = 'Wangige',
  slug = 'wangige',
  updated_at = datetime('now')
WHERE id = 'br_nakuru' OR slug = 'nakuru';

-- Update any product_stock rows still pointing to br_nakuru
-- Note: product_stock uses (product_id, branch_id) primary key.
-- Renaming the branch id would orphan stock rows, so we recreate them
-- with the new branch id if needed. Since we changed branch.id above,
-- existing rows with branch_id='br_nakuru' would now point at a non-existent branch.
-- Handle by copying them to the new id first, then deleting old.

INSERT OR IGNORE INTO product_stock (product_id, branch_id, quantity, updated_at)
SELECT product_id, 'br_wangige', quantity, updated_at
FROM product_stock
WHERE branch_id = 'br_nakuru';

DELETE FROM product_stock WHERE branch_id = 'br_nakuru';

-- Update orders that were assigned to the old branch
UPDATE orders SET branch_id = 'br_wangige' WHERE branch_id = 'br_nakuru';
SQL

# =============================================================================
# 2. Rename HTML file: nakuru.html → wangige.html
# =============================================================================
if [ -f public/branches/nakuru.html ]; then
  echo "▶ Renaming public/branches/nakuru.html → wangige.html"
  git mv public/branches/nakuru.html public/branches/wangige.html 2>/dev/null || mv public/branches/nakuru.html public/branches/wangige.html
fi

# =============================================================================
# 3. Rewrite wangige.html with correct content
# =============================================================================
echo "▶ Rewriting public/branches/wangige.html"
cat > public/branches/wangige.html <<'WANGIGEHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Wangige Branch · NEVER GIVE UP ENTERPRISE</title>
  <meta name="description" content="Visit NEVER GIVE UP ENTERPRISE Wangige branch — premium drums, containers, jikos, and farming tools." />
  <link rel="icon" href="/assets/images/favicon.ico" />
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <script>
    tailwind.config = { theme: { extend: { fontFamily: { sans: ["Inter","system-ui","sans-serif"] }, colors: { brand: { 500:"#3b82f6",600:"#2563eb",700:"#1d4ed8" }, leaf: { 500:"#10b981",600:"#059669" } } } } };
  </script>
</head>
<body class="font-sans bg-slate-50 text-slate-800 flex flex-col min-h-screen">
  <header class="bg-white shadow-sm sticky top-0 z-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex justify-between h-16 items-center">
      <a href="/" class="flex items-center gap-3">
        <span class="h-10 w-10 rounded-full bg-gradient-to-r from-brand-500 to-leaf-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
        <span class="hidden sm:block leading-tight"><span class="block text-sm font-extrabold">NEVER GIVE UP</span><span class="block text-[11px] text-slate-500 tracking-widest">ENTERPRISE</span></span>
      </a>
      <nav class="hidden md:flex gap-6 text-sm font-medium">
        <a href="/products/" class="hover:text-brand-600">Products</a>
        <a href="/branches/" class="text-brand-600">Branches</a>
        <a href="/about.html" class="hover:text-brand-600">About</a>
        <a href="/services.html" class="hover:text-brand-600">Services</a>
        <a href="/contact.html" class="hover:text-brand-600">Contact</a>
      </nav>
      <a href="/cart/" class="relative p-2"><i class="fa-solid fa-cart-shopping text-lg"></i><span id="cart-count" class="absolute -top-1 -right-1 bg-brand-600 text-white text-[10px] font-bold h-5 min-w-[20px] px-1 rounded-full flex items-center justify-center" style="display:none;">0</span></a>
    </div>
  </header>

  <main class="flex-1">
    <section class="bg-gradient-to-br from-orange-50 via-white to-blue-50 py-14 px-4 sm:px-6 lg:px-8">
      <div class="max-w-6xl mx-auto">
        <nav class="text-sm text-slate-500 mb-4"><a href="/" class="hover:text-brand-600">Home</a> / <a href="/branches/" class="hover:text-brand-600">Branches</a> / <span class="text-slate-800">Wangige</span></nav>
        <div class="grid md:grid-cols-2 gap-8 items-center">
          <div>
            <span class="inline-flex items-center gap-1 px-3 py-1 rounded-full bg-orange-100 text-orange-700 text-xs font-bold tracking-widest uppercase">
              <i class="fa-solid fa-location-dot"></i> Branch
            </span>
            <h1 class="mt-4 text-4xl sm:text-5xl font-extrabold">Wangige Branch</h1>
            <p class="mt-3 text-lg text-slate-600">Same quality, same prices, same dedication — now serving Wangige and the surrounding area.</p>
            <div class="mt-6 space-y-2 text-sm">
              <div class="flex items-center gap-3"><i class="fa-solid fa-location-dot text-brand-600 w-4"></i><span>Wangige, Kenya</span></div>
              <div class="flex items-center gap-3"><i class="fa-solid fa-phone text-brand-600 w-4"></i><a href="tel:+254704787011" class="hover:text-brand-600">+254 704 787 011</a></div>
              <div class="flex items-center gap-3"><i class="fa-brands fa-whatsapp text-leaf-600 w-4"></i><a href="https://wa.me/254721200637" target="_blank" class="hover:text-brand-600">+254 721 200 637 (WhatsApp)</a></div>
              <div class="flex items-start gap-3"><i class="fa-regular fa-clock text-brand-600 w-4 mt-1"></i><span>Mon–Fri 8:00–17:00<br />Sat 9:00–14:00<br />Sun closed</span></div>
            </div>
            <div class="mt-6 flex flex-col sm:flex-row gap-3">
              <a href="/products/" class="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700">
                <i class="fa-solid fa-box"></i> Shop products
              </a>
              <a href="https://www.google.com/maps/search/Wangige,+Kenya" target="_blank" rel="noopener" class="inline-flex items-center justify-center gap-2 px-5 py-2.5 rounded-md bg-white text-slate-800 font-semibold ring-1 ring-slate-200 hover:ring-brand-300">
                <i class="fa-solid fa-map"></i> Get directions
              </a>
            </div>
          </div>
          <div class="rounded-2xl overflow-hidden shadow-lg ring-1 ring-slate-100">
            <img src="/assets/images/products/250ltrs.jpg" alt="Drum at Wangige branch" class="w-full h-80 object-cover" />
          </div>
        </div>
      </div>
    </section>

    <section class="py-12 px-4 sm:px-6 lg:px-8 bg-white">
      <div class="max-w-6xl mx-auto">
        <h2 class="text-2xl font-extrabold text-center">What's in stock at Wangige</h2>
        <p class="text-center text-slate-500 mt-1">Popular items available now</p>
        <div id="wangige-products" class="mt-8 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5"></div>
      </div>
    </section>

    <script type="module">
      import { addToCart } from '/assets/js/brand.js';
      import { productImage } from '/assets/js/product-images.js';
      async function load() {
        const grid = document.getElementById('wangige-products');
        try {
          const res = await fetch('/api/products');
          const payload = await res.json();
          const products = (payload.data || []).slice(6, 12);
          grid.innerHTML = products.map(function(p) {
            const img = productImage(p);
            const safe = String(p.name).replace(/[&<>"']/g, function(c){return ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"})[c];});
            return '<article class="bg-white rounded-xl overflow-hidden ring-1 ring-slate-100 shadow-sm"><a href="/products/' + encodeURIComponent(p.id) + '.html"><div class="aspect-[4/3] bg-slate-100"><img src="' + img + '" alt="' + safe + '" class="w-full h-full object-cover" loading="lazy" /></div></a><div class="p-4"><h3 class="font-semibold line-clamp-2">' + safe + '</h3><div class="mt-3 flex items-center justify-between"><span class="font-bold text-brand-600">KES ' + Number(p.price||0).toLocaleString() + '</span><button type="button" data-add=\'' + JSON.stringify({id:p.id,name:p.name,price:Number(p.price)||0,image:img}).replace(/"/g,'&quot;') + '\' class="text-xs font-semibold bg-leaf-500 text-white px-3 py-1.5 rounded-md hover:bg-leaf-600">Add</button></div></div></article>';
          }).join('');
          grid.querySelectorAll('[data-add]').forEach(function(b){
            b.addEventListener('click', function(){
              try { addToCart(JSON.parse(b.getAttribute('data-add'))); b.textContent = '✓'; setTimeout(function(){b.textContent='Add';}, 1200); } catch(e){}
            });
          });
        } catch (e) { grid.innerHTML = '<p class="col-span-full text-center text-slate-500">Could not load products.</p>'; }
      }
      load();
    </script>
  </main>

  <footer class="bg-slate-900 text-slate-300 pt-14 pb-8 px-4 sm:px-6 lg:px-8">
    <div class="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-10">
      <div>
        <div class="flex items-center gap-3">
          <span class="h-10 w-10 rounded-full bg-gradient-to-r from-brand-500 to-leaf-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
          <div><div class="text-sm font-extrabold text-white tracking-wide">NEVER GIVE UP</div><div class="text-[11px] text-slate-400 tracking-widest">ENTERPRISE</div></div>
        </div>
        <p class="mt-4 text-sm text-slate-400 leading-relaxed">High-quality drums, containers, jikos and farming tools. Serving Kikuyu, Wangige, and all of Kenya with dedication.</p>
      </div>
      <div>
        <h3 class="text-sm font-bold text-white tracking-wide">Quick links</h3>
        <nav class="mt-4 grid grid-cols-2 gap-y-2 text-sm">
          <a href="/products/" class="hover:text-white">Products</a>
          <a href="/branches/" class="hover:text-white">Branches</a>
          <a href="/about.html" class="hover:text-white">About</a>
          <a href="/services.html" class="hover:text-white">Services</a>
          <a href="/gallery.html" class="hover:text-white">Gallery</a>
          <a href="/blog.html" class="hover:text-white">Blog</a>
          <a href="/faq.html" class="hover:text-white">FAQ</a>
          <a href="/contact.html" class="hover:text-white">Contact</a>
        </nav>
      </div>
      <div>
        <h3 class="text-sm font-bold text-white tracking-wide">Visit / Contact</h3>
        <ul class="mt-4 space-y-2 text-sm text-slate-400">
          <li class="flex items-start gap-2"><i class="fa-solid fa-location-dot text-brand-400 mt-1"></i> Wangige, Kenya</li>
          <li class="flex items-start gap-2"><i class="fa-solid fa-phone text-brand-400 mt-1"></i> <a href="tel:+254704787011" class="hover:text-white">+254 704 787 011</a></li>
          <li class="flex items-start gap-2"><i class="fa-regular fa-envelope text-brand-400 mt-1"></i> <a href="mailto:nopgiveup@gmail.com" class="hover:text-white">nopgiveup@gmail.com</a></li>
          <li class="flex items-start gap-2"><i class="fa-regular fa-clock text-brand-400 mt-1"></i><span>Mon–Fri 8:00–17:00<br />Sat 9:00–14:00<br />Sun closed</span></li>
        </ul>
      </div>
    </div>
    <div class="max-w-7xl mx-auto mt-12 pt-6 border-t border-slate-800 text-center text-xs text-slate-500">
      &copy; <span data-year>2026</span> NEVER GIVE UP ENTERPRISE. All rights reserved.
    </div>
  </footer>
  <script type="module">import "/assets/js/brand.js";</script>
</body>
</html>
WANGIGEHTML

# =============================================================================
# 4. Update every file that mentions Nakuru → Wangige
# =============================================================================
echo "▶ Updating references from Nakuru → Wangige across the site"

# Text replacements in HTML files (name + link)
find public -name "*.html" -type f | while read -f; do
  # Skip legacy pages (frozen snapshot)
  case "$f" in *legacy*) continue ;; esac
  # Replace text
  sed -i 's/Nakuru/Wangige/g' "$f"
  sed -i 's/nakuru/wangige/g' "$f"
done

# Also update CSS/JS files
find public -name "*.js" -o -name "*.css" | while read -f; do
  sed -i 's/Nakuru/Wangige/g' "$f"
  sed -i 's/nakuru/wangige/g' "$f"
done

# =============================================================================
# 5. Update the branches index page (branch picker)
# =============================================================================
echo "▶ Rewriting public/branches/index.html"
cat > public/branches/index.html <<'BRANCHINDEX'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Our Branches · NEVER GIVE UP ENTERPRISE</title>
  <meta name="description" content="Visit NEVER GIVE UP ENTERPRISE in Kikuyu or Wangige — premium drums, containers, jikos, and farming tools." />
  <link rel="icon" href="/assets/images/favicon.ico" />
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
</head>
<body class="font-sans bg-slate-50 text-slate-800 flex flex-col min-h-screen">
  <header class="bg-white shadow-sm sticky top-0 z-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex justify-between h-16 items-center">
      <a href="/" class="flex items-center gap-3">
        <span class="h-10 w-10 rounded-full bg-gradient-to-r from-blue-500 to-emerald-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
        <span class="hidden sm:block leading-tight"><span class="block text-sm font-extrabold">NEVER GIVE UP</span><span class="block text-[11px] text-slate-500 tracking-widest">ENTERPRISE</span></span>
      </a>
      <nav class="hidden md:flex gap-6 text-sm font-medium">
        <a href="/products/" class="hover:text-blue-600">Products</a>
        <a href="/branches/" class="text-blue-600">Branches</a>
        <a href="/about.html" class="hover:text-blue-600">About</a>
        <a href="/services.html" class="hover:text-blue-600">Services</a>
        <a href="/contact.html" class="hover:text-blue-600">Contact</a>
      </nav>
      <a href="/cart/" class="relative p-2"><i class="fa-solid fa-cart-shopping text-lg"></i></a>
    </div>
  </header>

  <main class="flex-1">
    <section class="bg-gradient-to-br from-green-50 via-white to-blue-50 py-16 px-4 sm:px-6 lg:px-8">
      <div class="max-w-4xl mx-auto text-center">
        <span class="inline-flex items-center px-3 py-1 rounded-full bg-white ring-1 ring-slate-200 text-xs font-bold tracking-widest text-blue-600 uppercase">Our branches</span>
        <h1 class="mt-4 text-4xl sm:text-5xl font-extrabold">Visit us in person</h1>
        <p class="mt-3 text-slate-600 max-w-2xl mx-auto">Two locations, one standard of quality. Same products, same prices, same friendly service.</p>
      </div>
    </section>

    <section class="py-12 px-4 sm:px-6 lg:px-8 bg-white">
      <div class="max-w-6xl mx-auto grid md:grid-cols-2 gap-6">
        <a href="/branches/kikuyu.html" class="group block rounded-2xl overflow-hidden ring-1 ring-slate-100 bg-white shadow-sm hover:shadow-xl transition">
          <div class="aspect-[16/9] bg-gradient-to-br from-blue-500 to-emerald-500 relative">
            <div class="absolute inset-0 flex items-center justify-center">
              <i class="fa-solid fa-location-dot text-white text-6xl opacity-80"></i>
            </div>
          </div>
          <div class="p-6">
            <div class="flex items-center justify-between">
              <h2 class="text-2xl font-extrabold">Kikuyu Branch</h2>
              <i class="fa-solid fa-arrow-right text-blue-600 group-hover:translate-x-1 transition"></i>
            </div>
            <p class="mt-1 text-slate-500">Kikuyu, Kenya</p>
            <div class="mt-4 flex items-center gap-2 text-sm text-slate-600">
              <i class="fa-regular fa-clock text-emerald-600"></i>
              <span>Mon–Fri 8:00–17:00 · Sat 9:00–14:00</span>
            </div>
            <div class="mt-2 flex items-center gap-2 text-sm text-slate-600">
              <i class="fa-solid fa-phone text-emerald-600"></i>
              <span>+254 704 787 011</span>
            </div>
          </div>
        </a>

        <a href="/branches/wangige.html" class="group block rounded-2xl overflow-hidden ring-1 ring-slate-100 bg-white shadow-sm hover:shadow-xl transition">
          <div class="aspect-[16/9] bg-gradient-to-br from-orange-400 to-blue-600 relative">
            <div class="absolute inset-0 flex items-center justify-center">
              <i class="fa-solid fa-location-dot text-white text-6xl opacity-80"></i>
            </div>
          </div>
          <div class="p-6">
            <div class="flex items-center justify-between">
              <h2 class="text-2xl font-extrabold">Wangige Branch</h2>
              <i class="fa-solid fa-arrow-right text-blue-600 group-hover:translate-x-1 transition"></i>
            </div>
            <p class="mt-1 text-slate-500">Wangige, Kenya</p>
            <div class="mt-4 flex items-center gap-2 text-sm text-slate-600">
              <i class="fa-regular fa-clock text-emerald-600"></i>
              <span>Mon–Fri 8:00–17:00 · Sat 9:00–14:00</span>
            </div>
            <div class="mt-2 flex items-center gap-2 text-sm text-slate-600">
              <i class="fa-solid fa-phone text-emerald-600"></i>
              <span>+254 721 200 637</span>
            </div>
          </div>
        </a>
      </div>
    </section>

    <section class="py-12 px-4 sm:px-6 lg:px-8 bg-slate-50">
      <div class="max-w-4xl mx-auto text-center">
        <h2 class="text-2xl font-extrabold">Can't visit in person?</h2>
        <p class="mt-2 text-slate-600">We deliver countrywide. Or order online and pick up at either branch.</p>
        <div class="mt-6 flex flex-col sm:flex-row gap-3 justify-center">
          <a href="/products/" class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-md bg-blue-600 text-white font-semibold hover:bg-blue-700">
            <i class="fa-solid fa-box"></i> Shop products
          </a>
          <a href="/contact.html" class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-md bg-white text-slate-800 font-semibold ring-1 ring-slate-200 hover:ring-blue-300">
            <i class="fa-regular fa-message"></i> Contact us
          </a>
        </div>
      </div>
    </section>
  </main>

  <footer class="bg-slate-900 text-slate-300 pt-14 pb-8 px-4 sm:px-6 lg:px-8">
    <div class="max-w-7xl mx-auto text-center text-xs text-slate-500">
      &copy; <span data-year>2026</span> NEVER GIVE UP ENTERPRISE. All rights reserved.
    </div>
  </footer>
</body>
</html>
BRANCHINDEX

# =============================================================================
# 6. Update seed file for future re-seeds
# =============================================================================
if [ -f migrations/0042_seed.sql ]; then
  echo "▶ Updating migrations/0042_seed.sql"
  sed -i "s/'br_nakuru'/'br_wangige'/g" migrations/0042_seed.sql
  sed -i "s/Nakuru/Wangige/g" migrations/0042_seed.sql
  sed -i "s/nakuru/wangige/g" migrations/0042_seed.sql
fi

# =============================================================================
# 7. Update any source / API files that referenced Nakuru
# =============================================================================
find functions src -type f \( -name "*.js" \) 2>/dev/null | while read -f; do
  sed -i 's/Nakuru/Wangige/g' "$f"
  sed -i 's/nakuru/wangige/g' "$f"
done

# =============================================================================
# 8. Update the sitemap
# =============================================================================
if [ -f public/sitemap.xml ]; then
  sed -i 's|/branches/nakuru.html|/branches/wangige.html|g' public/sitemap.xml
fi

# =============================================================================
# Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add migrations/0048_rename_nakuru_to_wangige.sql 2>/dev/null || true
git add public/branches/wangige.html public/branches/nakuru.html public/branches/index.html 2>/dev/null || true
git add public/ migrations/0042_seed.sql functions/ src/ public/sitemap.xml 2>/dev/null || true

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Branch rename written."
echo ""
echo "Deploy:"
echo "  1. npx wrangler d1 migrations apply ngu-platform-db --remote"
echo "  2. npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  3. git add -A; git commit -m 'feat: rename Nakuru branch to Wangige'; git push origin main"
echo ""
