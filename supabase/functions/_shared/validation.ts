import { HttpError } from "./http.ts";

export function record(value: unknown, name = "body"): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "INVALID_BODY", `${name} must be a JSON object.`);
  }
  return value as Record<string, unknown>;
}

export function requiredString(value: unknown, name: string, maxLength = 4000) {
  if (typeof value !== "string" || value.trim().length === 0 || value.length > maxLength) {
    throw new HttpError(422, "INVALID_FIELD", `${name} must be a non-empty string of at most ${maxLength} characters.`);
  }
  return value.trim();
}

export function optionalString(value: unknown, name: string, maxLength = 4000) {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string" || value.length > maxLength) {
    throw new HttpError(422, "INVALID_FIELD", `${name} must be a string of at most ${maxLength} characters.`);
  }
  return value.trim();
}

export function uuid(value: unknown, name: string) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new HttpError(422, "INVALID_UUID", `${name} must be a valid UUID.`);
  }
  return value;
}

export function number(value: unknown, name: string, min: number, max: number) {
  const parsed = typeof value === "number" ? value : typeof value === "string" && value.trim() !== "" ? Number(value) : NaN;
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
    throw new HttpError(422, "INVALID_NUMBER", `${name} must be between ${min} and ${max}.`);
  }
  return parsed;
}

export function integer(value: unknown, name: string, min: number, max: number) {
  const parsed = number(value, name, min, max);
  if (!Number.isInteger(parsed)) throw new HttpError(422, "INVALID_INTEGER", `${name} must be an integer.`);
  return parsed;
}

export function isoDate(value: unknown, name: string) {
  const stringValue = requiredString(value, name, 80);
  const date = new Date(stringValue);
  if (Number.isNaN(date.getTime())) throw new HttpError(422, "INVALID_DATE", `${name} must be an ISO timestamp.`);
  return date.toISOString();
}

export function enumValue<T extends string>(value: unknown, name: string, allowed: readonly T[]) {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new HttpError(422, "INVALID_ENUM", `${name} must be one of: ${allowed.join(", ")}.`);
  }
  return value as T;
}

export function uuidArray(value: unknown, name: string, maxLength = 50) {
  if (!Array.isArray(value) || value.length > maxLength) {
    throw new HttpError(422, "INVALID_ARRAY", `${name} must be an array of at most ${maxLength} items.`);
  }
  return value.map((item, index) => uuid(item, `${name}[${index}]`));
}
