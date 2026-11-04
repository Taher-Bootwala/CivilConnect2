export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, OPTIONS",
};

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

export function jsonResponse(data: unknown, status = 200, headers: HeadersInit = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", ...headers },
  });
}

export function errorResponse(error: unknown, requestId: string) {
  if (error instanceof HttpError) {
    return jsonResponse({
      error: { code: error.code, message: error.message, details: error.details },
      request_id: requestId,
    }, error.status);
  }
  console.error(JSON.stringify({ request_id: requestId, error }));
  return jsonResponse({
    error: { code: "INTERNAL_ERROR", message: "An unexpected error occurred." },
    request_id: requestId,
  }, 500);
}

export async function readJson<T>(request: Request): Promise<T> {
  try {
    return await request.json() as T;
  } catch {
    throw new HttpError(400, "INVALID_JSON", "Request body must contain valid JSON.");
  }
}

export function requestId(request: Request) {
  return request.headers.get("x-request-id") ?? crypto.randomUUID();
}

export function withHttpHandler(
  handler: (request: Request, requestId: string) => Promise<Response>,
) {
  return async (request: Request) => {
    const id = requestId(request);
    if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    try {
      return await handler(request, id);
    } catch (error) {
      return errorResponse(error, id);
    }
  };
}
