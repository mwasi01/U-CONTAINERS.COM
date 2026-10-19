export const CHANNEL_TYPES = ['dm', 'product', 'order', 'branch', 'department', 'social'];
export function channelKey(type, ref) { return `${type}:${ref}`; }
