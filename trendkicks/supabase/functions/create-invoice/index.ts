import {
  adminClient,
  applyInvoice,
  cors,
  env,
  getOrder,
  HttpError,
  json,
  reconcileRefund,
  sandboxKey,
  userClient,
  xendit,
} from "../_shared/runtime.ts";
import type { VerifiedInvoice } from "../_shared/payment_rules.ts";

export async function createInvoice(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }
  try {
    const { client, user } = await userClient(request);
    if (Number(request.headers.get("content-length") ?? 0) > 32768) {
      throw new HttpError(413, "Checkout request is too large.");
    }
    const raw = await request.text();
    if (raw.length > 32768) {
      throw new HttpError(413, "Checkout request is too large.");
    }
    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      throw new HttpError(400, "Invalid checkout request.");
    }
    if (
      !body || !["create", "resume", "cancel", "refund"].includes(body.action)
    ) {
      throw new HttpError(400, "Unsupported checkout action.");
    }
    sandboxKey(env("XENDIT_SECRET_KEY")); // Fail before reserving inventory.
    const admin = adminClient();
    let orderId = body.order_id;
    if (body.action === "create") {
      const advanced = body.advanced === true;
      if (!advanced && (body.voucher_code || body.points)) {
        throw new HttpError(
          400,
          "Enable advanced shopping to use vouchers or points.",
        );
      }
      const { data, error } = await client.rpc(
        advanced ? "tk_checkout_v2" : "tk_create_order",
        {
          p_items: body.items,
          p_delivery: body.delivery,
          p_method: "XENDIT",
          p_request_key: body.request_key,
          p_expected_total_cents: body.expected_total_cents,
          ...(advanced
            ? {
              p_code: body.voucher_code ?? "",
              p_points: body.points ?? 0,
              p_address: body.address_id ?? null,
            }
            : {}),
        },
      );
      if (error) {
        throw new HttpError(
          400,
          error.code === "P0001"
            ? error.message
            : "Please check your items and delivery details.",
        );
      }
      orderId = data;
    }
    if (typeof orderId !== "string" || !/^[0-9a-f-]{36}$/i.test(orderId)) {
      throw new HttpError(400, "Invalid order ID.");
    }
    let order = await getOrder(client, orderId);
    if (body.action === "refund") {
      const { data: isAdmin, error } = await client.rpc("tk_is_admin");
      if (error || !isAdmin) throw new HttpError(403, "Admin access required.");
      await reconcileRefund(admin, String(body.refund_id ?? ""), orderId);
      return json({ order: await getOrder(client, orderId) });
    }
    // RLS grants admins read access; payment actions still require actual ownership.
    if (order.user_id !== user.id || order.payment_method !== "XENDIT") {
      throw new HttpError(
        403,
        "This payment belongs to a different account or payment method.",
      );
    }

    if (body.action === "cancel") {
      if (
        order.invoice_id && order.payment_status === "PENDING" &&
        order.status !== "CANCELLED"
      ) {
        let invoice = await xendit(
          `/v2/invoices/${encodeURIComponent(order.invoice_id)}`,
        ) as VerifiedInvoice;
        if (invoice.status === "PENDING") {
          invoice = await xendit(
            `/invoices/${encodeURIComponent(order.invoice_id)}/expire!`,
            { method: "POST" },
          ) as VerifiedInvoice;
        }
        await applyInvoice(admin, order, invoice);
        order = await getOrder(client, orderId);
      }
      const { error } = await client.rpc("tk_cancel_order", {
        p_order: orderId,
      });
      if (error) {
        throw new HttpError(
          400,
          error.code === "P0001"
            ? error.message
            : "Cancellation could not be completed.",
        );
      }
      return json({ order: await getOrder(client, orderId) });
    }
    if (
      order.invoice_id &&
      ["PENDING", "PAID", "REFUND_REQUIRED"].includes(order.payment_status)
    ) {
      await applyInvoice(
        admin,
        order,
        await xendit(
          `/v2/invoices/${encodeURIComponent(order.invoice_id)}`,
        ) as VerifiedInvoice,
      );
      return json({ order: await getOrder(client, orderId) });
    }
    if (order.status === "CANCELLED" || order.payment_status !== "PENDING") {
      return json({ order });
    }
    const { data: claimed, error: claimError } = await admin.rpc(
      "tk_claim_invoice",
      { p_order: orderId },
    );
    if (claimError || !claimed) {
      throw new HttpError(
        409,
        "Your payment link is being prepared. Please try again in a moment.",
      );
    }
    // Recover a link created before a timeout/crash, using our stable external ID.
    const previous = await xendit(
      `/v2/invoices?external_id=${encodeURIComponent(orderId)}`,
    ) as VerifiedInvoice[];
    if (!Array.isArray(previous)) {
      throw new HttpError(
        502,
        "Unexpected response from the payment provider.",
      );
    }
    let invoice = previous.find((i) => i.external_id === orderId);
    if (!invoice) {
      const configuredMethods = (Deno.env.get("XENDIT_PAYMENT_METHODS") ?? "")
        .split(",").map((s) => s.trim()).filter(Boolean);
      invoice = await xendit("/v2/invoices", {
        method: "POST",
        body: JSON.stringify({
          external_id: order.id,
          amount: order.total_cents / 100,
          currency: "PHP",
          invoice_duration: 3600,
          should_send_email: false,
          payer_email: user.email,
          description: `Trend Kicks order TK-${
            order.id.substring(0, 8).toUpperCase()
          }`,
          ...(configuredMethods.length
            ? { payment_methods: configuredMethods }
            : {}),
        }),
      }) as VerifiedInvoice;
    }
    await applyInvoice(admin, order, invoice);
    return json({ order: await getOrder(client, orderId) });
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status);
    }
    console.error(
      "Checkout error",
      error instanceof Error ? error.name : "UnknownError",
    );
    return json({
      error:
        "Checkout could not finish. Check your order history before placing another order.",
    }, 503);
  }
}
if (Deno.env.get("TK_TESTING") !== "1") Deno.serve(createInvoice);
