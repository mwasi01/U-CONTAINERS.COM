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
