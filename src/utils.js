export const uuid = () => crypto.randomUUID();
export const nowISO = () => new Date().toISOString();
export const parseJSON = (req) => req.json().catch(() => null);
