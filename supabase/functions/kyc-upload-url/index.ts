import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, adminClient, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, requiredString, integer, enumValue } from "../_shared/validation.ts";

const documentTypes = ["identity", "address", "tax", "bank", "background_check", "other"] as const;
const mimeExtensions: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "application/pdf": "pdf",
};

type UploadRequest = { documentType: unknown; mimeType: unknown; byteSize: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST for KYC upload URLs.");
  const { client, user } = await requireUser(request);
  const body = record(await readJson<UploadRequest>(request));
  const documentType = enumValue(body.documentType, "documentType", documentTypes);
  const mimeType = requiredString(body.mimeType, "mimeType", 100);
  const extension = mimeExtensions[mimeType];
  if (!extension) throw new HttpError(422, "UNSUPPORTED_FILE_TYPE", "Only PDF, JPEG, and PNG documents are accepted.");
  const byteSize = integer(body.byteSize, "byteSize", 1, 10_000_000);
  const labor = await client.from("labor_profiles").select("user_id").eq("user_id", user.id).maybeSingle();
  if (!assertNoDatabaseError(labor)) throw new HttpError(409, "ONBOARDING_REQUIRED", "Create a professional profile before uploading KYC documents.");

  const storagePath = `kyc/${user.id}/${crypto.randomUUID()}.${extension}`;
  const storage = adminClient().storage.from("kyc-documents");
  const signed = await storage.createSignedUploadUrl(storagePath);
  if (signed.error || !signed.data) throw new HttpError(503, "UPLOAD_URL_UNAVAILABLE", "Could not create a secure upload URL.");
  return jsonResponse({ document_type: documentType, storage_path: storagePath, token: signed.data.token, declared_bytes: byteSize, max_bytes: 10_000_000 }, 201);
}));
