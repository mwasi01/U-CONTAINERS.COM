// Maps product IDs (or slugs) to real photo paths under /assets/images/products/
export const PRODUCT_IMAGES = {
  'p_250l_open':   '/assets/images/products/250ltrs open.jpg',
  'p_250l_closed': '/assets/images/products/250ltrs.jpg',
  'p_170l_funiko': '/assets/images/products/170ltrs.jpg',
  'p_120l':        '/assets/images/products/120ltrs.jpg',
  'p_small_jiko':  '/assets/images/products/small jiko.jpg',
  'p_std_jiko':    '/assets/images/products/stardand jiko.jpg',
  'p_med_jiko':    '/assets/images/products/mediumsized jiko.jpg',
  'p_size13_jiko': '/assets/images/products/size13jiko.jpg',
  'p_spade':       '/assets/images/products/spade.jpg',
  'p_rake_sm':     '/assets/images/products/small rake.jpg',
  'p_rake_big':    '/assets/images/products/big rake.jpg',
  'p_fork_jembe':  '/assets/images/products/fork jembe.jpg',
  'p_vifuniko':    '/assets/images/products/vifuniko.jpg',
  'p_metal_drum':  '/assets/images/products/metallic drum.jpg',
};

export function productImage(product) {
  if (!product) return '/assets/images/logo.svg';
  if (product.image) return product.image;
  return PRODUCT_IMAGES[product.id] || PRODUCT_IMAGES[product.slug] || '/assets/images/logo.svg';
}
