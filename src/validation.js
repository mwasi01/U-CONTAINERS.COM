export function validate(body, schema) {
  const errors = {};
  for (const [key, rule] of Object.entries(schema)) {
    const value = body?.[key];
    if (rule.required && !value) { errors[key] = 'required'; continue; }
    if (value && rule.type && typeof value !== rule.type) errors[key] = `must be ${rule.type}`;
    if (value && rule.min !== undefined && String(value).length < rule.min) errors[key] = `min ${rule.min}`;
  }
  return { ok: Object.keys(errors).length === 0, errors };
}
