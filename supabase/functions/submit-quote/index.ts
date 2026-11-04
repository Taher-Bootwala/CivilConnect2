import { withHttpHandler, HttpError, jsonResponse, readJson } from "../_shared/http.ts";
import { requireUser, assertNoDatabaseError } from "../_shared/supabase.ts";
import { record, uuid, requiredString, optionalString, number, integer } from "../_shared/validation.ts";

type QuoteLine = { lineType: unknown; description: unknown; quantity: unknown; unitAmountPaise: unknown; priceGuideItemId?: unknown };
type QuoteRequest = { bookingId: unknown; lineItems: unknown; outOfRangeReason?: unknown };

Deno.serve(withHttpHandler(async (request) => {
  if (request.method !== "POST") throw new HttpError(405, "METHOD_NOT_ALLOWED", "Use POST to submit a quote.");
  const { client } = await requireUser(request);
  const body = record(await readJson<QuoteRequest>(request));
  const bookingId = uuid(body.bookingId, "bookingId");
  if (!Array.isArray(body.lineItems) || body.lineItems.length === 0 || body.lineItems.length > 50) throw new HttpError(422, "INVALID_LINE_ITEMS", "Provide between one and fifty quote line items.");
  const lineItems = body.lineItems.map((value, index) => {
    const line = record(value, `lineItems[${index}]`) as unknown as QuoteLine;
    const lineType = requiredString(line.lineType, `lineItems[${index}].lineType`, 20);
    if (!["labor", "material", "visiting", "add_on"].includes(lineType)) throw new HttpError(422, "INVALID_LINE_TYPE", "Unsupported quote line type.");
    return {
      line_type: lineType,
      description: requiredString(line.description, `lineItems[${index}].description`, 500),
      quantity: number(line.quantity, `lineItems[${index}].quantity`, 0.001, 100000),
      unit_amount_paise: integer(line.unitAmountPaise, `lineItems[${index}].unitAmountPaise`, 0, 1000000000),
      price_guide_item_id: line.priceGuideItemId == null ? null : uuid(line.priceGuideItemId, `lineItems[${index}].priceGuideItemId`),
    };
  });
  const result = await client.rpc("submit_booking_quote", {
    booking_uuid: bookingId,
    quote_lines: lineItems,
    out_of_range_reason: optionalString(body.outOfRangeReason, "outOfRangeReason", 1000),
  });
  return jsonResponse({ quote: assertNoDatabaseError(result) }, 201);
}));
