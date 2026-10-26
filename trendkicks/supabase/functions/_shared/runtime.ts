import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.57.4";
import { validateInvoice, type VerifiedInvoice } from "./payment_rules.ts";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}
export function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new HttpError(
      503,
      "The payment service is not configured. Please contact the store.",
    );
  }
  return value;
}
export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
export function adminClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
export async function userClient(request: Request) {
  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) {
    throw new HttpError(401, "Please sign in to continue.");
  }
  const client = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error } = await client.auth.getUser(
    authorization.substring(7),
  );
  if (error || !user) {
    throw new HttpError(401, "Your session has expired. Please sign in again.");
  }
  return { client, user };
}
export async function xendit(
  path: string,
  init: RequestInit = {},
): Promise<unknown> {
  const key = sandboxKey(env("XENDIT_SECRET_KEY"));
  const response = await fetch(`https://api.xendit.co${path}`, {
    ...init,
    headers: {
      Authorization: `Basic ${btoa(key + ":")}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) {
    // Do not forward provider internals, tokens, or customer payloads to the browser.
    console.error("Xendit request failed", response.status, path.split("?")[0]);
    throw new HttpError(
      502,
      "The payment provider could not complete this request. Your reserved order is in your order history.",
    );
  }
  return response.json();
}
export async function getOrder(client: SupabaseClient, id: string) {
  const { data, error } = await client.from("tk_orders").select("*").eq(
    "id",
    id,
  ).single();
  if (error || !data) throw new HttpError(404, "Order not found.");
  return data;
}
export async function applyInvoice(
  admin: SupabaseClient,
  order: { id: string; total_cents: number; invoice_id?: string | null },
  invoice: VerifiedInvoice,
) {
  validateInvoice(invoice, order);
  const { error: attachError } = await admin.rpc("tk_attach_invoice", {
    p_order: order.id,
    p_invoice: invoice.id,
    p_url: invoice.invoice_url,
  });
  if (attachError) {
    throw new HttpError(
      503,
      "Couldn’t save the payment link. Please retry from your order.",
    );
  }
  const { error } = await admin.rpc("tk_record_payment", {
    p_order: order.id,
    p_invoice: invoice.id,
    p_status: invoice.status,
    p_amount_cents: Math.round(invoice.amount * 100),
    p_currency: invoice.currency,
  });
  if (error) {
    throw new HttpError(
      503,
      "Couldn’t update the payment status. Please check your order again shortly.",
    );
  }
}

export function sandboxKey(key: string): string {
  if (!key.startsWith("xnd_development_")) {
    throw new HttpError(
      503,
      "This school project accepts Xendit test keys only.",
    );
  }
  return key;
}

export type VerifiedRefund = {
  id: string;
  status: string;
  currency: string;
  invoice_id: string;
  amount: number;
};

export function validateRefund(refund: VerifiedRefund, order: {
  invoice_id?: string | null;
  total_cents: number;
}): number {
  const cents = Math.round(refund.amount * 100);
  if (
    !refund.id || refund.status !== "SUCCEEDED" || refund.currency !== "PHP" ||
    !order.invoice_id || refund.invoice_id !== order.invoice_id ||
    !Number.isFinite(refund.amount) || !Number.isSafeInteger(cents) ||
    cents <= 0 ||
    cents > order.total_cents ||
    Math.abs(refund.amount * 100 - cents) > 0.000001
  ) {
    throw new HttpError(
      409,
      "A successful PHP refund linked to this invoice is required.",
    );
  }
  return cents;
}

export async function reconcileRefund(
  admin: SupabaseClient,
  id: string,
  expectedOrder?: string,
) {
  if (!/^[a-zA-Z0-9_-]{1,120}$/.test(id)) {
    throw new HttpError(400, "Invalid refund ID.");
  }
  const refund = await xendit(
    `/refunds/${encodeURIComponent(id)}`,
  ) as VerifiedRefund;
  if (refund.id !== id || !refund.invoice_id) {
    throw new HttpError(
      409,
      "This refund has no verifiable invoice reference.",
    );
  }
  const { data: order, error } = await admin.from("tk_orders").select("*")
    .eq("invoice_id", refund.invoice_id).maybeSingle();
  if (error || !order || (expectedOrder && order.id !== expectedOrder)) {
    throw new HttpError(409, "Refund invoice does not match this order.");
  }
  const amount = validateRefund(refund, order);
  const { error: settlementError } = await admin.rpc("tk_confirm_refund", {
    p_order: order.id,
    p_reference: refund.id,
    p_amount: amount,
  });
  if (settlementError) {
    throw new HttpError(409, "Refund settlement could not be recorded.");
  }
}
