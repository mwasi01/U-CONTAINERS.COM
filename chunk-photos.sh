#!/usr/bin/env bash
# chunk-photos.sh — product photo upload via R2
set -euo pipefail
cd "$(dirname "$0")"
echo "▶ Repo root: $(pwd)"

# =============================================================================
# 1. Migration — add `image` column to products
# =============================================================================
echo "▶ Writing migrations/0047_product_image.sql"
cat > migrations/0047_product_image.sql <<'SQL'
-- 0047_product_image.sql — add image URL column to products
ALTER TABLE products ADD COLUMN image TEXT DEFAULT NULL;
SQL

# =============================================================================
# 2. Upload endpoint — POST /api/admin/products/:id/photo
# =============================================================================
echo "▶ Writing functions/api/admin/products/[id]/photo.js"
mkdir -p 'functions/api/admin/products/[id]'
cat > 'functions/api/admin/products/[id]/photo.js' <<'PHOTO'
import { jsonResponse, badRequest, forbidden, notFound, serverError } from '../../../../../src/errors.js';
import { getAuthUser } from '../../../../../src/auth.js';
import { db } from '../../../../../src/db.js';
import { nowISO } from '../../../../../src/utils.js';

const EDIT_ROLES = ['owner', 'admin', 'manager'];

async function requireEditor(ctx) {
  let user = ctx.data?.user;
  if (!user) {
    user = await getAuthUser(ctx);
    if (user) ctx.data.user = user;
  }
  if (!user || !EDIT_ROLES.includes(user.role)) throw forbidden('Admin access only');
  return user;
}

// POST /api/admin/products/:id/photo
// Accepts multipart/form-data with field "file"
// Uploads to R2 under products/<productId>-<timestamp>.<ext>
// Updates products.image to the public URL /media/products/<filename>
export async function onRequestPost(ctx) {
  const user = await requireEditor(ctx);

  const d = db(ctx.env);
  const product = await d.first('SELECT id, name FROM products WHERE id = ? AND deleted_at IS NULL', ctx.params.id);
  if (!product) throw notFound('Product not found');

  if (!ctx.env.MEDIA) throw serverError('R2 binding MEDIA not configured');

  const form = await ctx.request.formData().catch(() => null);
  if (!form) throw badRequest('Expected multipart/form-data');
  const file = form.get('file');
  if (!file || typeof file === 'string') throw badRequest('No file uploaded');

  const maxBytes = 5 * 1024 * 1024; // 5 MB
  if (file.size > maxBytes) throw badRequest('Image must be under 5 MB');

  const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/avif'];
  if (!allowed.includes(file.type)) throw badRequest('Only JPG, PNG, WEBP, or AVIF allowed');

  const ext = (file.type.split('/')[1] || 'jpg').replace('jpeg', 'jpg');
  const filename = `${ctx.params.id}-${Date.now()}.${ext}`;
  const key = `products/${filename}`;

  const arrayBuf = await file.arrayBuffer();

  try {
    await ctx.env.MEDIA.put(key, arrayBuf, {
      httpMetadata: { contentType: file.type },
    });
  } catch (err) {
    console.error('R2 upload failed', err);
    throw serverError('Upload failed: ' + err.message);
  }

  const url = `/media/${key}`;

  try {
    await d.run(
      'UPDATE products SET image = ?, updated_at = ?, updated_by = ? WHERE id = ?',
      url, nowISO(), user.sub || user.email, ctx.params.id
    );
  } catch (err) {
    console.error('DB update failed', err);
    throw serverError('Image saved but product update failed: ' + err.message);
  }

  return jsonResponse({ imageUrl: url, key, size: file.size, type: file.type });
}
PHOTO

# =============================================================================
# 3. Serve R2 assets at /media/* (functions/media/[[path]].js already exists)
# =============================================================================
echo "▶ Verifying functions/media/[[path]].js"
if [ -f 'functions/media/[[path]].js' ]; then
  echo "  ✓ exists — serves from env.MEDIA"
else
  echo "  ✗ missing — creating it"
  mkdir -p functions/media
  cat > 'functions/media/[[path]].js' <<'MEDIA'
export async function onRequestGet(ctx) {
  const path = ctx.params.path?.join('/') || '';
  if (!ctx.env.MEDIA) return new Response('R2 not configured', { status: 500 });
  const obj = await ctx.env.MEDIA.get(path);
  if (!obj) return new Response('Not found', { status: 404 });
  const headers = new Headers();
  obj.writeHttpMetadata(headers);
  headers.set('etag', obj.httpEtag);
  headers.set('Cache-Control', 'public, max-age=31536000, immutable');
  return new Response(obj.body, { headers });
}
MEDIA
fi

# =============================================================================
# 4. Update product-edit.html — add photo upload UI
# =============================================================================
echo "▶ Updating public/admin/product-edit.html"
# Insert photo section before the "Stock per branch" section
if ! grep -q 'id="photo-section"' public/admin/product-edit.html; then
  python3 - <<'PYEOF'
import re
path = 'public/admin/product-edit.html'
with open(path) as f:
    html = f.read()

photo_section = '''        <div class="pt-4 border-t border-slate-200" id="photo-section">
          <h2 class="text-sm font-bold mb-3">Product photo</h2>
          <div class="flex flex-col sm:flex-row gap-4 items-start">
            <div class="w-32 h-32 rounded-lg bg-slate-100 overflow-hidden flex items-center justify-center ring-1 ring-slate-200">
              <img id="current-photo" src="/assets/images/placeholder.svg" alt="Product" class="w-full h-full object-cover" />
            </div>
            <div class="flex-1">
              <input id="photo-input" type="file" accept="image/jpeg,image/png,image/webp,image/avif" class="block w-full text-sm text-slate-500 file:mr-3 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100" />
              <p class="text-xs text-slate-500 mt-2">JPG, PNG, WEBP, or AVIF. Max 5 MB.</p>
              <button type="button" id="upload-photo-btn" class="mt-3 inline-flex items-center gap-2 px-4 py-2 rounded-md bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700 disabled:opacity-50">
                <i class="fa-solid fa-cloud-upload-alt"></i> Upload photo
              </button>
              <p id="photo-status" class="text-xs mt-2 hidden"></p>
            </div>
          </div>
        </div>

'''

# Insert before the "Stock per branch" div
marker = '<div class="pt-4 border-t border-slate-200">\n          <h2 class="text-sm font-bold mb-3">Stock per branch</h2>'
if marker in html:
    html = html.replace(marker, photo_section + marker, 1)

# Add photo upload JS before the final load() call
upload_js = '''
    // Photo upload
    const photoInput = document.getElementById('photo-input');
    const uploadBtn = document.getElementById('upload-photo-btn');
    const photoStatus = document.getElementById('photo-status');
    const currentPhoto = document.getElementById('current-photo');

    function showPhotoStatus(text, isError) {
      photoStatus.textContent = text;
      photoStatus.classList.remove('hidden', 'text-red-600', 'text-emerald-600');
      photoStatus.classList.add(isError ? 'text-red-600' : 'text-emerald-600');
    }

    if (uploadBtn) {
      uploadBtn.addEventListener('click', async () => {
        const file = photoInput.files[0];
        if (!file) { showPhotoStatus('Choose a file first.', true); return; }
        uploadBtn.disabled = true;
        const original = uploadBtn.innerHTML;
        uploadBtn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Uploading…';
        try {
          const fd = new FormData();
          fd.append('file', file);
          const res = await fetch('/api/admin/products/' + encodeURIComponent(id) + '/photo', {
            method: 'POST',
            headers: { Authorization: 'Bearer ' + token },
            body: fd,
          });
          const body = await res.json();
          if (!res.ok || body.error) throw new Error(body.error?.message || 'Upload failed');
          const url = body.data.imageUrl;
          currentPhoto.src = url + '?v=' + Date.now();
          showPhotoStatus('Photo uploaded ✓', false);
          photoInput.value = '';
        } catch (e) {
          showPhotoStatus(e.message, true);
        } finally {
          uploadBtn.disabled = false;
          uploadBtn.innerHTML = original;
        }
      });
    }

'''

# Insert before the final load() call
marker2 = '    load();\n  </script>'
if marker2 in html:
    html = html.replace(marker2, upload_js + marker2, 1)

# Set initial photo when the product loads
marker3 = "        form.status.value = product.status || 'active';\n\n        renderStock();"
if marker3 in html:
    html = html.replace(marker3, "        form.status.value = product.status || 'active';\n\n        if (product.image) currentPhoto.src = product.image;\n\n        renderStock();", 1)

with open(path, 'w') as f:
    f.write(html)
print('  ✓ product-edit.html updated with photo section')
PYEOF
fi

# =============================================================================
# 5. Update product-new.html — allow upload after creation
# =============================================================================
echo "▶ Updating public/admin/product-new.html (redirect to edit after create)"
# Change redirect so user lands on edit page where they can add photo
if grep -q "location.href = '/admin/products.html';" public/admin/product-new.html; then
  sed -i "s|location.href = '/admin/products.html';|location.href = '/admin/product-edit.html?id=' + encodeURIComponent(body.data.id);|" public/admin/product-new.html
  echo "  ✓ product-new.html now redirects to edit page after creation"
fi

# =============================================================================
# Stage
# =============================================================================
echo ""
echo "▶ Staging files…"
git add migrations/0047_product_image.sql
git add 'functions/api/admin/products/[id]/photo.js'
git add 'functions/media/[[path]].js' 2>/dev/null || true
git add public/admin/product-edit.html
git add public/admin/product-new.html

echo ""
echo "▶ Diff summary:"
git status --short

echo ""
echo "✅ Photo upload written."
echo ""
echo "Next (PowerShell):"
echo "  1. Apply migration:"
echo "     npx wrangler d1 migrations apply ngu-platform-db --remote"
echo "  2. Deploy:"
echo "     npx wrangler pages deploy public --project-name u-containers-com --branch main --commit-dirty=true"
echo "  3. Commit + push:"
echo "     git add -A; git commit -m 'feat: product photo upload via R2'; git push origin main"
echo ""

