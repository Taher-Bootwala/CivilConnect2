import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, adminClient, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, requiredString, integer, enumValue } from "../_shared/validation.ts";

const documentTypes = ["identity", "address", "tax", "bank", "background_check", "other"] as const;
const mimeTypes = ["image/jpeg", "image/png", "application/pdf"] as const;
type DocumentInput = { documentType: unknown; storagePath: unknown; mimeType: unknown; byteSize: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to submit KYC documents.");
  const { client, user } = await requireUser(request);
  const body = record(await readJson<{ documents: unknown }>(request));
  if (!Array.isArray(body.documents) || body.documents.length === 0 || body.documents.length > 10) {
    throw new HttpError(422, "INVALID_DOCUMENTS", "Submit between one and ten KYC documents.");
  }
  const documents = body.documents.map((value, index) => {
    const item = record(value, `documents[${index}]`) as unknown as DocumentInput;
    const documentType = enumValue(item.documentType, `documents[${index}].documentType`, documentTypes);
    const storagePath = requiredString(item.storagePath, `documents[${index}].storagePath`, 500);
    if (!storagePath.startsWith(`kyc/${user.id}/`)) throw new HttpError(403, "INVALID_STORAGE_PATH", "KYC documents must belong to the authenticated professional.");
    const mimeType = enumValue(item.mimeType, `documents[${index}].mimeType`, mimeTypes);
    const byteSize = integer(item.byteSize, `documents[${index}].byteSize`, 1, 10_000_000);
    return { documentType, storagePath, mimeType, byteSize };
  });

  const storage = adminClient().storage.from("kyc-documents");
  const folders = await storage.list(`kyc/${user.id}`, { limit: 100 });
  if (folders.error) throw new HttpError(503, "STORAGE_UNAVAILABLE", "KYC storage could not be checked.");
  const available = new Set((folders.data ?? []).map((entry) => `kyc/${user.id}/${entry.name}`));
  for (const document of documents) {
    if (!available.has(document.storagePath)) throw new HttpError(422, "DOCUMENT_NOT_UPLOADED", `Document ${document.storagePath} is not present in private storage.`);
  }

  const result = await client.from("labor_kyc").insert(documents.map((document) => ({
    labor_id: user.id,
    document_type: document.documentType,
    storage_path: document.storagePath,
    mime_type: document.mimeType,
    byte_size: document.byteSize,
    status: "submitted",
  }))).select("id, document_type, status, created_at");
  return jsonResponse({ documents: assertNoDatabaseError(result), kyc_status: "submitted" }, 201);
}));
