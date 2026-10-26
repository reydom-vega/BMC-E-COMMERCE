export interface VerifiedInvoice {
  id: string;
  external_id: string;
  amount: number;
  currency: string;
  status: string;
  invoice_url: string;
  paid_amount?: number;
}

export function isCheckoutUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" &&
      (url.hostname === "xendit.co" || url.hostname.endsWith(".xendit.co"));
  } catch {
    return false;
  }
}

export function validateInvoice(
  invoice: VerifiedInvoice,
  order: { id: string; total_cents: number; invoice_id?: string | null },
): void {
  if (
    !invoice.id || invoice.external_id !== order.id ||
    invoice.currency !== "PHP" ||
    !Number.isFinite(invoice.amount) ||
    Math.round(invoice.amount * 100) !== order.total_cents ||
    (order.invoice_id && order.invoice_id !== invoice.id) ||
    !isCheckoutUrl(invoice.invoice_url)
  ) {
    throw new Error("Invoice does not match this order.");
  }
  if (
    ["PAID", "SETTLED"].includes(invoice.status) &&
    invoice.paid_amount != null &&
    (!Number.isFinite(invoice.paid_amount) ||
      Math.round(invoice.paid_amount * 100) < order.total_cents)
  ) {
    throw new Error("The received payment is less than the order total.");
  }
}

export function tokensEqual(received: string, expected: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(received), b = encoder.encode(expected);
  let difference = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    difference |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return difference === 0 && b.length > 0;
}
