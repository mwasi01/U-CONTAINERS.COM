export const info  = (msg, meta = {}) => console.log(JSON.stringify({ level: 'info',  msg, ...meta }));
export const warn  = (msg, meta = {}) => console.log(JSON.stringify({ level: 'warn',  msg, ...meta }));
export const error = (msg, meta = {}) => console.log(JSON.stringify({ level: 'error', msg, ...meta }));
