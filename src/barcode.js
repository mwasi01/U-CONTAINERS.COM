export const encodePayload = (kind, value) => JSON.stringify({ kind, value, at: new Date().toISOString() });
export const decodePayload = (raw) => { try { return JSON.parse(raw); } catch { return { kind: 'unknown', value: raw }; } };
