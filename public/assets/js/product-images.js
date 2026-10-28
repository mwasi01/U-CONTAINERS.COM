// Maps product IDs to real photo paths under /assets/images/products/
// Products without a photo fall back to the branded placeholder.
export const PRODUCT_IMAGES = {
  'p_250l_drum':      '/assets/images/products/250ltrs.jpg',
  'p_170l_drum':      '/assets/images/products/170ltrs.jpg',
  'p_120l_drum':      '/assets/images/products/120ltrs.jpg',
  'p_80l_drum':       '/assets/images/products/1000litres open drum.jpg',
  'p_50l_drum':       null,
  'p_metal_drum':     '/assets/images/products/metallic drum.jpg',
  'p_1000l_tank':     '/assets/images/products/IBC Square Water Tanks 1000 Litre with Galvanized Frame and HDPE Tank.avif',
  'p_bucket_short':   null,
  'p_bucket_long':    null,
  'p_bucket_10l':     null,
  'p_bucket_20l':     null,
  'p_dirty_bucket':   null,
  'p_mtungi_20l':     null,
  'p_mtungi_10l':     null,
  'p_mtungi_40l':     null,
  'p_vibuyu_5l':      null,
  'p_kasuku_4l':      null,
  'p_jiko_small':     '/assets/images/products/small jiko.jpg',
  'p_jiko_standard':  '/assets/images/products/stardand jiko.jpg',
  'p_jiko_medium':    '/assets/images/products/mediumsized jiko.jpg',
  'p_jiko_size12':    '/assets/images/products/size13jiko.jpg',
  'p_jiko_size13':    '/assets/images/products/size13jiko.jpg',
  'p_jiko_size15':    '/assets/images/products/size13jiko.jpg',
  'p_spade':          null,
  'p_rake_big':       null,
  'p_rake_small':     null,
  'p_fork_jembe':     null,
  'p_slasher':        null,
  'p_vifuniko_metal': '/assets/images/products/vifuniko.jpg',
  'p_mabati':         null,
};

export function productImage(product) {
  if (!product) return '/assets/images/placeholder.svg';
  if (product.image) return product.image;
  const mapped = PRODUCT_IMAGES[product.id] || PRODUCT_IMAGES[product.slug];
  return mapped || '/assets/images/placeholder.svg';
}
