import { HttpError } from "./http.ts";

function credentials() {
  const keyId = Deno.env.get("RAZORPAY_KEY_ID");
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");
  if (!keyId || !keySecret) throw new HttpError(503, "PAYMENT_PROVIDER_NOT_CONFIGURED", "Razorpay is not configured on the server.");
  return { keyId, keySecret };
}

export async function razorpayRequest<T>(path: string, method: "GET" | "POST", body?: Record<string, unknown>): Promise<T> {
  const { keyId, keySecret } = credentials();
  const response = await fetch(`https://api.razorpay.com/v1${path}`, {
    method,
    headers: {
      Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    console.error(JSON.stringify({ provider_status: response.status, provider_code: payload?.error?.code }));
    throw new HttpError(502, "PAYMENT_PROVIDER_ERROR", "Razorpay rejected the request.");
  }
  return payload as T;
}

export async function verifyHmac(rawBody: string, signature: string, secret: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return expected === signature.toLowerCase();
}

export function razorpayPublicKey() {
  const key = Deno.env.get("RAZORPAY_KEY_ID");
  if (!key) throw new HttpError(503, "PAYMENT_PROVIDER_NOT_CONFIGURED", "Razorpay is not configured on the server.");
  return key;
}
