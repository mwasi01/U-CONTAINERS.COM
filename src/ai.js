export async function enrichImage(env, imageBuffer) {
  if (!env.AI) throw new Error('Workers AI binding missing');
  const result = await env.AI.run('@cf/unum/uform-gen2-qwen-500m', {
    image: [...new Uint8Array(imageBuffer)],
    prompt: 'Describe this product briefly with a title, category, and suggested price in KES.',
  });
  return result;
}
