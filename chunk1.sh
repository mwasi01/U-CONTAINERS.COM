#!/usr/bin/env bash
# chunk1.sh — writes NEVER GIVE UP branded homepage, products page, seed migration
# Run from repo root: bash chunk1.sh
set -euo pipefail

cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

# Sanity
test -d public     || { echo "FATAL: public/ missing"; exit 1; }
test -d migrations || { echo "FATAL: migrations/ missing"; exit 1; }
test -d functions  || { echo "FATAL: functions/ missing"; exit 1; }

# =============================================================================
# 1. public/_headers
# =============================================================================
echo "▶ Writing public/_headers"
cat > public/_headers <<'HEADERS'
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
  Permissions-Policy: geolocation=(), microphone=(), camera=(self)
  Content-Security-Policy: default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com https://cdn.tailwindcss.com; script-src 'self' 'unsafe-inline' https://cdn.tailwindcss.com; font-src 'self' data: https://fonts.gstatic.com https://cdnjs.cloudflare.com; connect-src 'self' https:; frame-src https://www.google.com; object-src 'none'; base-uri 'self'; frame-ancestors 'none'

/assets/*
  Cache-Control: public, max-age=300

/*.html
  Cache-Control: public, max-age=0, must-revalidate
HEADERS

# =============================================================================
# 2. public/assets/js/brand.js
# =============================================================================
echo "▶ Writing public/assets/js/brand.js"
mkdir -p public/assets/js
cat > public/assets/js/brand.js <<'BRANDJS'
// Shared NEVER GIVE UP ENTERPRISE script
const CART_KEY = 'ngu.cart.v1';

export function readCart() {
  try { return JSON.parse(localStorage.getItem(CART_KEY)) || []; }
  catch { return []; }
}

export function writeCart(items) {
  localStorage.setItem(CART_KEY, JSON.stringify(items));
  document.dispatchEvent(new CustomEvent('cart:updated', { detail: items }));
}

export function addToCart(product, qty = 1) {
  const items = readCart();
  const existing = items.find((i) => i.id === product.id);
  if (existing) existing.qty += qty;
  else items.push({ id: product.id, name: product.name, price: product.price, image: product.image || '', qty });
  writeCart(items);
}

export function cartCount() {
  return readCart().reduce((sum, i) => sum + i.qty, 0);
}

export function cartTotal() {
  return readCart().reduce((sum, i) => sum + i.price * i.qty, 0);
}

function updateCartBadge() {
  const badge = document.getElementById('cart-count');
  if (badge) {
    const n = cartCount();
    badge.textContent = String(n);
    badge.style.display = n > 0 ? 'inline-flex' : 'none';
  }
}

function initSmoothScroll() {
  document.querySelectorAll('a[href^="#"]').forEach((a) => {
    a.addEventListener('click', (e) => {
      const t = document.querySelector(a.getAttribute('href'));
      if (t) { e.preventDefault(); t.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
    });
  });
}

function initYear() {
  document.querySelectorAll('[data-year]').forEach((el) => { el.textContent = new Date().getFullYear(); });
}

function initMobileMenu() {
  const btn = document.getElementById('menu-btn');
  const menu = document.getElementById('mobile-menu');
  if (btn && menu) btn.addEventListener('click', () => menu.classList.toggle('hidden'));
}

document.addEventListener('DOMContentLoaded', () => {
  updateCartBadge();
  initSmoothScroll();
  initYear();
  initMobileMenu();
  document.addEventListener('cart:updated', updateCartBadge);
});
BRANDJS

# =============================================================================
# 3. migrations/0043_seed_products.sql
# =============================================================================
echo "▶ Writing migrations/0043_seed_products.sql"
cat > migrations/0043_seed_products.sql <<'SEEDSQL'
-- 0043_seed_products.sql — real NEVER GIVE UP ENTERPRISE products
INSERT OR IGNORE INTO products (id, name, slug, description, category_slug, price, status, created_at, updated_at) VALUES
  ('p_250l_open',   '250L Open Plastic Drum',    '250l-open-plastic-drum',   'Capacity: 250 liters. Heavy-duty open-top plastic drum with reinforced handles.', 'drums-containers', 3500, 'active', datetime('now'), datetime('now')),
  ('p_250l_closed', '250L Closed Plastic Drum',  '250l-closed-plastic-drum', 'Capacity: 250 liters. Closed drum with security lock and removable lid.',        'drums-containers', 4000, 'active', datetime('now'), datetime('now')),
  ('p_170l_funiko', '170L Funiko Drum',          '170l-funiko-drum',         'Capacity: 170 liters. Reinforced bottom and side handles.',                     'drums-containers', 3200, 'active', datetime('now'), datetime('now')),
  ('p_120l',        '120L Plastic Drum',         '120l-plastic-drum',        'Capacity: 120 liters. Screw-on lid and built-in handles.',                       'drums-containers', 2800, 'active', datetime('now'), datetime('now')),
  ('p_small_jiko',  'Small Jiko',                'small-jiko',               'Compact charcoal jiko, ideal for single person use.',                             'jikos',             950, 'active', datetime('now'), datetime('now')),
  ('p_std_jiko',    'Standard Jiko',             'standard-jiko',            'Family-size charcoal jiko with efficient airflow.',                               'jikos',            1200, 'active', datetime('now'), datetime('now')),
  ('p_med_jiko',    'Medium Jiko',               'medium-jiko',              'Extra capacity jiko with double ceramic insulation.',                             'jikos',            1500, 'active', datetime('now'), datetime('now')),
  ('p_size13_jiko', 'Size 13 Jiko',              'size-13-jiko',             'Commercial-grade charcoal chamber, wide cooking surface.',                        'jikos',            2000, 'active', datetime('now'), datetime('now')),
  ('p_spade',       'Spade',                     'spade',                    'Steel-headed spade with reinforced handle.',                                      'farming-tools',     850, 'active', datetime('now'), datetime('now')),
  ('p_rake_sm',     'Small Rake',                'small-rake',               'Compact rake for garden cleanup.',                                                'farming-tools',     600, 'active', datetime('now'), datetime('now')),
  ('p_rake_big',    'Big Rake',                  'big-rake',                 'Heavy-duty rake for field work.',                                                 'farming-tools',     750, 'active', datetime('now'), datetime('now')),
  ('p_fork_jembe',  'Fork Jembe',                'fork-jembe',               'Traditional four-tine fork jembe for soil cultivation.',                          'farming-tools',     900, 'active', datetime('now'), datetime('now')),
  ('p_vifuniko',    'Vifuniko (Tops/Covers)',    'vifuniko',                 'Plastic drum tops and covers - various sizes.',                                   'accessories',       250, 'active', datetime('now'), datetime('now')),
  ('p_metal_drum',  'Metal Drum',                'metal-drum',               'Heavy-duty painted metal drum for industrial use.',                               'drums-containers', 5500, 'active', datetime('now'), datetime('now'));
SEEDSQL

# =============================================================================
# 4. public/index.html
# =============================================================================
echo "▶ Writing public/index.html"
cat > public/index.html <<'HOMEHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>NEVER GIVE UP ENTERPRISE · Premium Drums, Containers, Jikos & Farming Tools</title>
  <meta name="description" content="Premium quality drums, containers, jikos and farming tools in Kikuyu, Kenya. Best prices for storage and agricultural solutions — NEVER GIVE UP ENTERPRISE." />
  <meta name="keywords" content="drums, containers, jikos, farming tools, Kenya, Kikuyu, NEVER GIVE UP ENTERPRISE" />
  <meta property="og:title" content="NEVER GIVE UP ENTERPRISE" />
  <meta property="og:description" content="Premium quality drums, containers, jikos and farming tools." />
  <meta property="og:image" content="/assets/images/og-image.png" />
  <link rel="icon" href="/assets/images/favicon.ico" />
  <link rel="manifest" href="/manifest.webmanifest" />
  <script src="https://cdn.tailwindcss.com"></script>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <script>
    tailwind.config = {
      theme: { extend: {
        fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
        colors: {
          brand: { 50: '#eff6ff', 100: '#dbeafe', 500: '#3b82f6', 600: '#2563eb', 700: '#1d4ed8' },
          leaf: { 500: '#10b981', 600: '#059669', 700: '#047857' },
        },
      } },
    };
  </script>
  <style>
    html { scroll-behavior: smooth; }
    body::after {
      content: "NEVER GIVE UP"; position: fixed; bottom: 20px; right: 20px;
      font-size: 11px; font-weight: 800; letter-spacing: 3px; color: rgba(0,0,0,0.06);
      transform: rotate(-90deg); transform-origin: left bottom;
      pointer-events: none; z-index: 9999;
    }
    .card-hover { transition: transform .25s, box-shadow .25s; }
    .card-hover:hover { transform: translateY(-4px); box-shadow: 0 20px 40px -20px rgba(0,0,0,.15); }
    .gradient-brand { background: linear-gradient(90deg, #3b82f6 0%, #10b981 100%); }
    .text-gradient-brand { background: linear-gradient(90deg, #3b82f6, #10b981); -webkit-background-clip: text; background-clip: text; color: transparent; }
  </style>
</head>
<body class="font-sans bg-slate-50 text-slate-800 antialiased">

  <header class="bg-white shadow-sm sticky top-0 z-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16 items-center">
        <a href="/" class="flex items-center gap-3">
          <span class="h-10 w-10 rounded-full gradient-brand text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
          <span class="hidden sm:block leading-tight">
            <span class="block text-sm font-extrabold text-slate-900 tracking-wide">NEVER GIVE UP</span>
            <span class="block text-[11px] text-slate-500 tracking-widest">ENTERPRISE</span>
          </span>
        </a>
        <nav class="hidden md:flex items-center gap-7 text-sm font-medium text-slate-700">
          <a href="/products/" class="hover:text-brand-600">Products</a>
          <a href="/branches/" class="hover:text-brand-600">Branches</a>
          <a href="/about.html" class="hover:text-brand-600">About</a>
          <a href="/services.html" class="hover:text-brand-600">Services</a>
          <a href="/gallery.html" class="hover:text-brand-600">Gallery</a>
          <a href="/blog.html" class="hover:text-brand-600">Blog</a>
          <a href="/contact.html" class="hover:text-brand-600">Contact</a>
        </nav>
        <div class="flex items-center gap-3">
          <a href="/cart/" class="relative p-2 text-slate-600 hover:text-brand-600" aria-label="Cart">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
            <span id="cart-count" class="absolute -top-1 -right-1 bg-brand-600 text-white text-[10px] font-bold h-5 min-w-[20px] px-1 rounded-full flex items-center justify-center" style="display:none;">0</span>
          </a>
          <a href="/account/" class="hidden sm:inline-flex items-center gap-1 text-sm font-medium text-slate-700 hover:text-brand-600"><i class="fa-regular fa-user"></i> Account</a>
          <button id="menu-btn" class="md:hidden p-2 text-slate-600" aria-label="Menu"><i class="fa-solid fa-bars text-lg"></i></button>
        </div>
      </div>
      <div id="mobile-menu" class="hidden md:hidden pb-4 space-y-2 text-sm font-medium">
        <a href="/products/" class="block py-2 hover:text-brand-600">Products</a>
        <a href="/branches/" class="block py-2 hover:text-brand-600">Branches</a>
        <a href="/about.html" class="block py-2 hover:text-brand-600">About</a>
        <a href="/services.html" class="block py-2 hover:text-brand-600">Services</a>
        <a href="/gallery.html" class="block py-2 hover:text-brand-600">Gallery</a>
        <a href="/blog.html" class="block py-2 hover:text-brand-600">Blog</a>
        <a href="/contact.html" class="block py-2 hover:text-brand-600">Contact</a>
        <a href="/account/" class="block py-2 hover:text-brand-600">Account</a>
      </div>
    </div>
  </header>

  <section class="relative overflow-hidden bg-gradient-to-br from-green-50 via-white to-blue-50">
    <div class="absolute -top-20 -left-20 w-80 h-80 bg-brand-500/10 rounded-full blur-3xl"></div>
    <div class="absolute -bottom-20 -right-20 w-96 h-96 bg-leaf-500/10 rounded-full blur-3xl"></div>
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 lg:py-28 relative z-10">
      <div class="text-center max-w-3xl mx-auto">
        <span class="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white shadow-sm ring-1 ring-slate-200 text-xs font-bold tracking-widest">
          <span class="text-brand-600">NEVER GIVE UP</span><span class="text-slate-700">ENTERPRISE</span>
        </span>
        <h1 class="mt-6 text-4xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight text-slate-900 leading-tight">
          Quality Containers &<br /><span class="text-gradient-brand">Gardening Solutions</span>
        </h1>
        <p class="mt-5 text-base sm:text-lg text-slate-600 max-w-2xl mx-auto">
          Premium drums, jikos, and farming tools for all your storage and agricultural needs.
          Proudly serving Kikuyu, Nakuru and beyond.
        </p>
        <div class="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
          <a href="/products/" class="inline-flex items-center justify-center px-7 py-3 rounded-md bg-brand-600 text-white font-semibold hover:bg-brand-700 shadow-md shadow-brand-600/20">Shop Products</a>
          <a href="/branches/" class="inline-flex items-center justify-center px-7 py-3 rounded-md bg-white text-slate-800 font-semibold ring-1 ring-slate-200 hover:ring-brand-300">Choose Branch</a>
        </div>
        <div class="mt-10 flex flex-wrap justify-center gap-x-8 gap-y-3 text-xs sm:text-sm text-slate-500">
          <span class="inline-flex items-center gap-2"><i class="fa-solid fa-truck text-leaf-600"></i> Countrywide delivery</span>
          <span class="inline-flex items-center gap-2"><i class="fa-solid fa-shield-halved text-leaf-600"></i> Quality guaranteed</span>
          <span class="inline-flex items-center gap-2"><i class="fa-solid fa-phone text-leaf-600"></i> +254 704 787 011</span>
        </div>
      </div>
    </div>
  </section>

  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-white">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-12">
        <span class="text-xs font-bold tracking-widest text-brand-600 uppercase">Featured Products</span>
        <h2 class="mt-2 text-3xl sm:text-4xl font-extrabold text-slate-900">Popular this week</h2>
        <div class="mt-3 h-1 w-20 mx-auto gradient-brand rounded"></div>
      </div>
      <div id="featured-products" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <div class="col-span-full text-center text-slate-500 py-10">Loading products…</div>
      </div>
      <div class="text-center mt-10">
        <a href="/products/" class="inline-flex items-center gap-2 text-brand-600 font-semibold hover:text-brand-700">Browse all products <i class="fa-solid fa-arrow-right"></i></a>
      </div>
    </div>
  </section>

  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-slate-50">
    <div class="max-w-7xl mx-auto">
      <div class="text-center mb-12">
        <span class="text-xs font-bold tracking-widest text-brand-600 uppercase">Categories</span>
        <h2 class="mt-2 text-3xl sm:text-4xl font-extrabold text-slate-900">What we sell</h2>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <a href="/products/drums-containers.html" class="bg-white rounded-xl p-6 text-center shadow-sm ring-1 ring-slate-100 card-hover"><div class="text-3xl mb-3"><i class="fa-solid fa-drum text-brand-600"></i></div><h3 class="font-bold text-slate-900">Drums & Containers</h3><p class="text-xs text-slate-500 mt-1">Storage solutions</p></a>
        <a href="/products/jikos.html" class="bg-white rounded-xl p-6 text-center shadow-sm ring-1 ring-slate-100 card-hover"><div class="text-3xl mb-3"><i class="fa-solid fa-fire text-orange-500"></i></div><h3 class="font-bold text-slate-900">Jikos</h3><p class="text-xs text-slate-500 mt-1">Charcoal cookers</p></a>
        <a href="/products/farming-tools.html" class="bg-white rounded-xl p-6 text-center shadow-sm ring-1 ring-slate-100 card-hover"><div class="text-3xl mb-3"><i class="fa-solid fa-seedling text-leaf-600"></i></div><h3 class="font-bold text-slate-900">Farming Tools</h3><p class="text-xs text-slate-500 mt-1">For the field</p></a>
        <a href="/products/accessories.html" class="bg-white rounded-xl p-6 text-center shadow-sm ring-1 ring-slate-100 card-hover"><div class="text-3xl mb-3"><i class="fa-solid fa-gears text-slate-500"></i></div><h3 class="font-bold text-slate-900">Accessories</h3><p class="text-xs text-slate-500 mt-1">Tops & parts</p></a>
      </div>
    </div>
  </section>

  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-white">
    <div class="max-w-7xl mx-auto">
      <div class="grid md:grid-cols-2 gap-10 items-center">
        <div>
          <span class="text-xs font-bold tracking-widest text-brand-600 uppercase">Our branches</span>
          <h2 class="mt-2 text-3xl sm:text-4xl font-extrabold text-slate-900">Two locations, one standard of quality</h2>
          <p class="mt-4 text-slate-600 leading-relaxed">Visit us in <strong>Kikuyu</strong> or <strong>Nakuru</strong>. Same products, same prices, same friendly service. Bulk orders and countrywide delivery available.</p>
          <div class="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-4">
            <a href="/branches/kikuyu.html" class="block rounded-xl p-5 bg-slate-50 ring-1 ring-slate-100 hover:ring-brand-300 card-hover"><div class="flex items-center justify-between"><div><div class="text-xs uppercase tracking-widest text-slate-500">Branch</div><div class="mt-1 font-bold text-slate-900">Kikuyu</div></div><i class="fa-solid fa-location-dot text-brand-600"></i></div><p class="text-xs text-slate-500 mt-3">Kikuyu, Kenya · Mon–Sat</p></a>
            <a href="/branches/nakuru.html" class="block rounded-xl p-5 bg-slate-50 ring-1 ring-slate-100 hover:ring-brand-300 card-hover"><div class="flex items-center justify-between"><div><div class="text-xs uppercase tracking-widest text-slate-500">Branch</div><div class="mt-1 font-bold text-slate-900">Nakuru</div></div><i class="fa-solid fa-location-dot text-brand-600"></i></div><p class="text-xs text-slate-500 mt-3">Nakuru, Kenya · Mon–Sat</p></a>
          </div>
        </div>
        <div class="rounded-2xl overflow-hidden shadow-lg ring-1 ring-slate-100">
          <img src="/assets/images/products/250ltrs open.jpg" alt="250L open drum" class="w-full h-72 object-cover" />
        </div>
      </div>
    </div>
  </section>

  <section class="py-16 px-4 sm:px-6 lg:px-8 bg-brand-600 text-white">
    <div class="max-w-4xl mx-auto text-center">
      <h2 class="text-3xl sm:text-4xl font-extrabold">NEVER GIVE UP ENTERPRISE</h2>
      <p class="mt-3 text-brand-100 text-lg">Persistence and quality — that's our promise to you.</p>
      <div class="mt-8 flex flex-col sm:flex-row gap-3 justify-center">
        <a href="/contact.html" class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-md bg-white text-brand-700 font-semibold hover:bg-brand-50"><i class="fa-regular fa-envelope"></i> Send us a message</a>
        <a href="https://wa.me/254721200637" target="_blank" rel="noopener" class="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-md bg-leaf-500 text-white font-semibold hover:bg-leaf-600"><i class="fa-brands fa-whatsapp"></i> Chat on WhatsApp</a>
      </div>
    </div>
  </section>

  <footer class="bg-slate-900 text-slate-300 pt-14 pb-8 px-4 sm:px-6 lg:px-8">
    <div class="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-10">
      <div>
        <div class="flex items-center gap-3">
          <span class="h-10 w-10 rounded-full gradient-brand text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
          <div><div class="text-sm font-extrabold text-white tracking-wide">NEVER GIVE UP</div><div class="text-[11px] text-slate-400 tracking-widest">ENTERPRISE</div></div>
        </div>
        <p class="mt-4 text-sm text-slate-400 leading-relaxed">High-quality drums, containers, jikos and farming tools. Serving Kikuyu, Nakuru, and all of Kenya with dedication.</p>
        <div class="mt-6 flex gap-3">
          <a href="#" class="h-9 w-9 flex items-center justify-center rounded-full bg-slate-800 hover:bg-brand-600 transition" aria-label="Facebook"><i class="fa-brands fa-facebook-f text-sm"></i></a>
          <a href="#" class="h-9 w-9 flex items-center justify-center rounded-full bg-slate-800 hover:bg-brand-600 transition" aria-label="Twitter"><i class="fa-brands fa-twitter text-sm"></i></a>
          <a href="#" class="h-9 w-9 flex items-center justify-center rounded-full bg-slate-800 hover:bg-brand-600 transition" aria-label="Instagram"><i class="fa-brands fa-instagram text-sm"></i></a>
          <a href="https://wa.me/254721200637" target="_blank" rel="noopener" class="h-9 w-9 flex items-center justify-center rounded-full bg-slate-800 hover:bg-leaf-600 transition" aria-label="WhatsApp"><i class="fa-brands fa-whatsapp text-sm"></i></a>
          <a href="https://www.tiktok.com/@user7054409306512" target="_blank" rel="noopener" class="h-9 w-9 flex items-center justify-center rounded-full bg-slate-800 hover:bg-slate-700 transition" aria-label="TikTok"><i class="fa-brands fa-tiktok text-sm"></i></a>
        </div>
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
          <a href="/privacy.html" class="hover:text-white">Privacy</a>
          <a href="/terms.html" class="hover:text-white">Terms</a>
        </nav>
      </div>
      <div>
        <h3 class="text-sm font-bold text-white tracking-wide">Visit / Contact</h3>
        <ul class="mt-4 space-y-2 text-sm text-slate-400">
          <li class="flex items-start gap-2"><i class="fa-solid fa-location-dot text-brand-400 mt-1"></i> Kikuyu, Kenya</li>
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

  <script type="module">
    import { addToCart } from '/assets/js/brand.js';
    async function renderFeatured() {
      const container = document.getElementById('featured-products');
      try {
        const res = await fetch('/api/products');
        const payload = await res.json();
        const products = (payload.data || []).slice(0, 6);
        if (!products.length) {
          container.innerHTML = `<div class="col-span-full text-center py-12"><p class="text-slate-500 mb-4">No products yet — coming soon.</p><a href="/contact.html" class="text-brand-600 font-semibold hover:underline">Contact us to order</a></div>`;
          return;
        }
        container.innerHTML = products.map((p) => `
          <article class="bg-white rounded-xl shadow-sm ring-1 ring-slate-100 card-hover overflow-hidden flex flex-col">
            <a href="/products/${encodeURIComponent(p.id)}.html" class="block"><div class="aspect-[4/3] bg-slate-100 overflow-hidden"><img src="${p.image || '/assets/images/logo.svg'}" alt="${escAttr(p.name)}" class="w-full h-full object-cover" loading="lazy" /></div></a>
            <div class="p-5 flex-1 flex flex-col">
              <h3 class="font-semibold text-slate-900 line-clamp-2">${escHtml(p.name)}</h3>
              <p class="text-xs text-slate-500 mt-1">${escHtml(p.category_slug || 'General')}</p>
              <div class="mt-auto pt-4 flex items-center justify-between">
                <span class="text-brand-600 font-bold">KES ${Number(p.price || 0).toLocaleString()}</span>
                <button type="button" data-add-product='${escAttr(JSON.stringify({ id: p.id, name: p.name, price: Number(p.price) || 0, image: p.image || '' }))}' class="text-xs font-semibold bg-leaf-500 text-white px-3 py-1.5 rounded-md hover:bg-leaf-600">Add to cart</button>
              </div>
            </div>
          </article>`).join('');
        container.querySelectorAll('[data-add-product]').forEach((btn) => {
          btn.addEventListener('click', () => {
            try { addToCart(JSON.parse(btn.getAttribute('data-add-product'))); const o=btn.textContent; btn.textContent='Added ✓'; btn.classList.add('bg-brand-600'); setTimeout(()=>{btn.textContent=o;btn.classList.remove('bg-brand-600');},1200); } catch {}
          });
        });
      } catch (err) {
        container.innerHTML = `<div class="col-span-full text-center text-red-500 py-10">Could not load products.</div>`;
      }
    }
    function escHtml(s=''){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
    function escAttr(s=''){return String(s).replace(/&/g,'&amp;').replace(/"/g,'&quot;');}
    renderFeatured();
  </script>
</body>
</html>
HOMEHTML

# =============================================================================
# 5. public/products/index.html
# =============================================================================
echo "▶ Writing public/products/index.html"
mkdir -p public/products
cat > public/products/index.html <<'PRODUCTSHTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Products · NEVER GIVE UP ENTERPRISE</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" />
  <script>
    tailwind.config = { theme: { extend: { fontFamily: { sans: ['Inter','system-ui','sans-serif'] }, colors: { brand: { 500:'#3b82f6',600:'#2563eb',700:'#1d4ed8' }, leaf: { 500:'#10b981',600:'#059669' } } } } };
  </script>
</head>
<body class="font-sans bg-slate-50 text-slate-800">
  <header class="bg-white shadow-sm sticky top-0 z-50">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex justify-between h-16 items-center">
      <a href="/" class="flex items-center gap-3">
        <span class="h-10 w-10 rounded-full bg-gradient-to-r from-brand-500 to-leaf-500 text-white font-extrabold flex items-center justify-center text-sm">NGU</span>
        <span class="hidden sm:block leading-tight"><span class="block text-sm font-extrabold">NEVER GIVE UP</span><span class="block text-[11px] text-slate-500 tracking-widest">ENTERPRISE</span></span>
      </a>
      <nav class="hidden md:flex gap-6 text-sm font-medium">
        <a href="/products/" class="text-brand-600">Products</a>
        <a href="/branches/" class="hover:text-brand-600">Branches</a>
        <a href="/about.html" class="hover:text-brand-600">About</a>
        <a href="/services.html" class="hover:text-brand-600">Services</a>
        <a href="/contact.html" class="hover:text-brand-600">Contact</a>
      </nav>
      <a href="/cart/" class="relative p-2"><i class="fa-solid fa-cart-shopping text-lg"></i><span id="cart-count" class="absolute -top-1 -right-1 bg-brand-600 text-white text-[10px] font-bold h-5 min-w-[20px] px-1 rounded-full flex items-center justify-center" style="display:none;">0</span></a>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
    <div class="mb-8">
      <h1 class="text-3xl sm:text-4xl font-extrabold">All products</h1>
      <p class="text-slate-500 mt-2">Real prices, real stock. Delivered countrywide.</p>
    </div>

    <div class="mb-6 flex flex-wrap gap-2">
      <a href="/products/" class="px-4 py-1.5 rounded-full bg-brand-600 text-white text-sm font-medium">All</a>
      <a href="/products/drums-containers.html" class="px-4 py-1.5 rounded-full bg-white ring-1 ring-slate-200 text-sm">Drums & Containers</a>
      <a href="/products/jikos.html" class="px-4 py-1.5 rounded-full bg-white ring-1 ring-slate-200 text-sm">Jikos</a>
      <a href="/products/farming-tools.html" class="px-4 py-1.5 rounded-full bg-white ring-1 ring-slate-200 text-sm">Farming Tools</a>
      <a href="/products/accessories.html" class="px-4 py-1.5 rounded-full bg-white ring-1 ring-slate-200 text-sm">Accessories</a>
    </div>

    <div id="product-grid" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6"></div>
  </main>

  <script type="module">
    import { addToCart } from '/assets/js/brand.js';
    const cat = new URLSearchParams(location.search).get('category')
      || (location.pathname.includes('drums-containers') ? 'drums-containers' : '')
      || (location.pathname.includes('jikos') ? 'jikos' : '')
      || (location.pathname.includes('farming-tools') ? 'farming-tools' : '')
      || (location.pathname.includes('accessories') ? 'accessories' : '');

    async function load() {
      const grid = document.getElementById('product-grid');
      try {
        const qs = cat ? `?category=${encodeURIComponent(cat)}` : '';
        const res = await fetch('/api/products' + qs);
        const payload = await res.json();
        const products = payload.data || [];
        if (!products.length) { grid.innerHTML = `<p class="col-span-full text-center text-slate-500 py-12">No products in this category yet.</p>`; return; }
        grid.innerHTML = products.map((p) => `
          <article class="bg-white rounded-xl overflow-hidden ring-1 ring-slate-100 shadow-sm hover:shadow-lg transition">
            <a href="/products/${encodeURIComponent(p.id)}.html"><div class="aspect-[4/3] bg-slate-100"><img src="${p.image || '/assets/images/logo.svg'}" alt="${esc(p.name)}" class="w-full h-full object-cover" loading="lazy" /></div></a>
            <div class="p-5">
              <h3 class="font-semibold line-clamp-2">${esc(p.name)}</h3>
              <p class="text-xs text-slate-500 mt-1">${esc(p.category_slug || 'General')}</p>
              <div class="mt-4 flex items-center justify-between">
                <span class="font-bold text-brand-600">KES ${Number(p.price||0).toLocaleString()}</span>
                <button type="button" data-add='${escAttr(JSON.stringify({id:p.id,name:p.name,price:Number(p.price)||0,image:p.image||''}))}' class="text-xs font-semibold bg-leaf-500 text-white px-3 py-1.5 rounded-md hover:bg-leaf-600">Add to cart</button>
              </div>
            </div>
          </article>`).join('');
        grid.querySelectorAll('[data-add]').forEach((b) => b.addEventListener('click', () => { try { addToCart(JSON.parse(b.getAttribute('data-add'))); b.textContent = 'Added ✓'; setTimeout(() => b.textContent = 'Add to cart', 1200); } catch {} }));
      } catch (e) { grid.innerHTML = `<p class="col-span-full text-center text-red-500 py-12">Failed to load products.</p>`; }
    }
    function esc(s=''){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
    function escAttr(s=''){return String(s).replace(/&/g,'&amp;').replace(/"/g,'&quot;');}
    load();
  </script>
</body>
</html>
PRODUCTSHTML

# =============================================================================
# 6. public/assets/js/products.js (stub)
# =============================================================================
echo "▶ Writing public/assets/js/products.js"
cat > public/assets/js/products.js <<'STUB'
// Legacy stub — new pages embed their own product loading logic.
export {};
STUB

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "✅ Chunk 1 files written:"
echo "  public/_headers"
echo "  public/index.html"
echo "  public/products/index.html"
echo "  public/assets/js/brand.js"
echo "  public/assets/js/products.js"
echo "  migrations/0043_seed_products.sql"
echo ""
echo "▶ Staging files…"
git add public/_headers public/index.html public/products/index.html public/assets/js/brand.js public/assets/js/products.js migrations/0043_seed_products.sql

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "▶ Next steps:"
echo "  1. From PowerShell:"
echo "       cd C:\\Users\\hp\\Desktop\\repo-tmp"
echo "       git commit -m \"brand: Tailwind homepage with NEVER GIVE UP identity + product seed\""
echo "       git push origin main"
echo "  2. Apply the new migration to production D1:"
echo "       npx wrangler d1 migrations apply ngu-platform-db --remote"
echo "       (answer Y)"
echo "  3. Wait ~90s for Cloudflare Pages rebuild, then:"
echo "       curl.exe https://ngucontainers.com/api/products"
echo "       start https://ngucontainers.com"
echo ""
