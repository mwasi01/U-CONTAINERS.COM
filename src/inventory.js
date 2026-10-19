export function generateSKU(category = 'GEN', branch = 'HQ', seq = 1) {
  const slug = (s) => String(s).toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4).padEnd(4, 'X');
  return `${slug(category)}-${slug(branch)}-${String(seq).padStart(4, '0')}`;
}
