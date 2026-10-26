import {
  isCheckoutUrl,
  tokensEqual,
  validateInvoice,
  type VerifiedInvoice,
} from "./payment_rules.ts";

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}
const invoice: VerifiedInvoice = {
  id: "invoice-1",
  external_id: "order-1",
  amount: 5615,
  currency: "PHP",
  status: "PAID",
  invoice_url: "https://invoice-staging.xendit.co/web/invoices/invoice-1",
  paid_amount: 5615,
};
const order = { id: "order-1", total_cents: 561500, invoice_id: "invoice-1" };
Deno.test("valid invoice has matching order, amount, currency, provider ID and URL", () => {
  validateInvoice(invoice, order);
});
Deno.test("tampered and mismatched invoice fields are rejected", () => {
  for (
    const patch of [
      { external_id: "other-order" },
      { amount: 1 },
      { currency: "IDR" },
      { id: "another-invoice" },
      { invoice_url: "https://xendit.co.evil.test/pay" },
      { paid_amount: 1 },
      { amount: NaN },
    ]
  ) {
    let rejected = false;
    try {
      validateInvoice({ ...invoice, ...patch }, order);
    } catch {
      rejected = true;
    }
    assert(rejected, `Expected rejection for ${JSON.stringify(patch)}`);
  }
});
Deno.test("only HTTPS Xendit hosts are accepted", () => {
  assert(isCheckoutUrl("https://checkout.xendit.co/abc"), "Valid subdomain");
  for (
    const url of [
      "http://checkout.xendit.co",
      "https://evilxendit.co",
      "https://xendit.co.evil.test",
      "javascript:alert(1)",
      "not a URL",
    ]
  ) assert(!isCheckoutUrl(url), url);
});
Deno.test("webhook token must be a nonempty exact match", () => {
  assert(tokensEqual("secret", "secret"), "Matching token");
  for (
    const [a, b] of [["", ""], ["secret", "secreT"], [
      "secret",
      "secret-longer",
    ], ["", "secret"]]
  ) assert(!tokensEqual(a, b), "Reject different/empty token");
});
