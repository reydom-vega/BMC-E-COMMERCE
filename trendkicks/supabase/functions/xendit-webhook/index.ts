import {
  adminClient,
  applyInvoice,
  env,
  getOrder,
  HttpError,
  json,
  reconcileRefund,
  xendit,
} from "../_shared/runtime.ts";
import { tokensEqual, type VerifiedInvoice } from "../_shared/payment_rules.ts";

export async function xenditWebhook(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }
  try {
    if (
      !tokensEqual(
        request.headers.get("x-callback-token") ?? "",
        env("XENDIT_WEBHOOK_TOKEN"),
      )
    ) return json({ error: "Unauthorized." }, 401);
    const raw = await request.text();
    if (raw.length > 32768) return json({ error: "Payload too large." }, 413);
    let event;
    try {
      event = JSON.parse(raw);
    } catch {
      return json({ error: "Invalid payload." }, 400);
    }
    if (event?.event === "refund.succeeded") {
      await reconcileRefund(adminClient(), String(event.data?.id ?? ""));
      return json({ received: true });
    }
    if (
      typeof event?.id !== "string" || !/^[a-zA-Z0-9_-]{1,120}$/.test(event.id)
    ) return json({ error: "Invalid invoice ID." }, 400);
    // The callback is authenticated, then rechecked against Xendit's authoritative API.
    // Do not accept a client-provided status, amount, or user ID as proof of payment.
    const invoice = await xendit(
      `/v2/invoices/${encodeURIComponent(event.id)}`,
    ) as VerifiedInvoice;
    if (!["PAID", "SETTLED", "EXPIRED"].includes(invoice.status)) {
      return json({ received: true });
    }
    if (!/^[0-9a-f-]{36}$/i.test(invoice.external_id)) {
      return json({ received: true, ignored: "unrelated invoice" });
    }
    const admin = adminClient();
    const { data: exists, error } = await admin.from("tk_orders").select("id")
      .eq("id", invoice.external_id).maybeSingle();
    if (error) throw new HttpError(503, "Couldn’t read the order.");
    if (!exists) return json({ received: true, ignored: "unrelated invoice" });
    const order = await getOrder(admin, invoice.external_id);
    await applyInvoice(admin, order, invoice);
    return json({ received: true });
  } catch (error) {
    console.error(
      "Webhook could not be processed",
      error instanceof Error ? error.name : "UnknownError",
    );
    return json({ error: "Webhook not processed. Please retry." }, 503);
  }
}
if (Deno.env.get("TK_TESTING") !== "1") Deno.serve(xenditWebhook);
