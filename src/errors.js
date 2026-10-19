export class ApiError extends Error {
  constructor(status, code, message, details = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const badRequest   = (m, d) => new ApiError(400, 'bad_request', m, d);
export const unauthorized = (m = 'Unauthorized') => new ApiError(401, 'unauthorized', m);
export const forbidden    = (m = 'Forbidden') => new ApiError(403, 'forbidden', m);
export const notFound     = (m = 'Not found') => new ApiError(404, 'not_found', m);
export const conflict     = (m) => new ApiError(409, 'conflict', m);
export const serverError  = (m = 'Internal error') => new ApiError(500, 'server_error', m);

export function jsonResponse(data, init = {}) {
  return new Response(JSON.stringify({ data, error: null }), {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init.headers || {}) },
  });
}

export function errorResponse(err) {
  const status = err.status || 500;
  const body = {
    data: null,
    error: {
      code: err.code || 'server_error',
      message: err.message || 'Internal error',
      details: err.details || null,
    },
  };
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
