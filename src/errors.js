export class ApiError extends Error {
  constructor(status, code, message) { super(message); this.status = status; this.code = code; }
}
export const badRequest   = (m) => new ApiError(400, 'bad_request', m);
export const unauthorized = (m = 'Unauthorized') => new ApiError(401, 'unauthorized', m);
export const forbidden    = (m = 'Forbidden') => new ApiError(403, 'forbidden', m);
export const notFound     = (m = 'Not found') => new ApiError(404, 'not_found', m);

export function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify({ data, error: null }), {
    status, headers: { 'Content-Type': 'application/json' },
  });
}
export function errorResponse(err) {
  return new Response(JSON.stringify({
    data: null,
    error: { code: err.code || 'server_error', message: err.message || 'Internal error' },
  }), { status: err.status || 500, headers: { 'Content-Type': 'application/json' } });
}
