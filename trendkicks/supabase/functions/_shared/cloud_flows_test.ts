import { sandboxKey, validateRefund } from "./runtime.ts";
import { sanitizeReviewImage } from "./review_image.ts";
import { decode, encode } from "npm:jpeg-js@0.4.4";
// @deno-types="npm:@types/pngjs@6.0.5"
import { PNG } from "npm:pngjs@7.0.0";

function assert(value: unknown, message = "Assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
function rejects(fn: () => unknown) {
  try {
    fn();
  } catch {
    return;
  }
  throw new Error("Expected rejection");
}

Deno.test("school sandbox and verified PHP refund rules", () => {
  assert(sandboxKey("xnd_development_test") === "xnd_development_test");
  rejects(() => sandboxKey("xnd_production_example"));
  const order = { invoice_id: "invoice-1", total_cents: 561500 };
  const refund = {
    id: "refund-1",
    invoice_id: "invoice-1",
    status: "SUCCEEDED",
    currency: "PHP",
    amount: 100,
  };
  assert(validateRefund(refund, order) === 10000);
  for (
    const patch of [
      { status: "PENDING" },
      { currency: "IDR" },
      { invoice_id: "other" },
      { amount: -1 },
      { amount: 5616 },
      { amount: NaN },
      { amount: 0.001 },
    ]
  ) {
    rejects(() => validateRefund({ ...refund, ...patch }, order));
  }
});

Deno.test("review photos fully decode JPEG/PNG without WASM, strip metadata and reject invalid bytes", async () => {
  const sample = await Deno.readFile(
    new URL("../../../assets/images/adidas-samba.jpg", import.meta.url),
  );
  const jpeg = await sanitizeReviewImage(sample);
  assert(jpeg.mime === "image/jpeg" && jpeg.width >= 100 && jpeg.height >= 100);
  const raw = decode(sample);
  const png = PNG.sync.write(
    { width: raw.width, height: raw.height, data: raw.data } as PNG,
  );
  const result = await sanitizeReviewImage(png);
  assert(result.width === jpeg.width && result.height === jpeg.height);
  const commented =
    encode({ ...raw, comments: ["strip-this-private-marker"] }, 82).data;
  const cleaned = await sanitizeReviewImage(commented);
  assert(!decode(cleaned.bytes).comments?.length);
  for (
    const bytes of [
      new Uint8Array(),
      new TextEncoder().encode("fake.jpg"),
      sample.slice(0, 60),
      new Uint8Array(5242881),
    ]
  ) {
    let rejected = false;
    try {
      await sanitizeReviewImage(bytes);
    } catch {
      rejected = true;
    }
    assert(rejected, "Invalid or oversized image accepted");
  }
});

Deno.test("cloud handlers enforce ownership and verified provider state without a PHP server", async (t) => {
  const saved = globalThis.fetch;
  const vars = [
    "TK_TESTING",
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "SUPABASE_SERVICE_ROLE_KEY",
    "XENDIT_SECRET_KEY",
    "XENDIT_WEBHOOK_TOKEN",
    "STORE_JOB_SECRET",
  ];
  const before = vars.map((key) => Deno.env.get(key));
  Deno.env.set("TK_TESTING", "1");
  Deno.env.set("SUPABASE_URL", "https://school.supabase.co");
  Deno.env.set("SUPABASE_ANON_KEY", "public-test-key");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "server-test-key");
  Deno.env.set("XENDIT_SECRET_KEY", "xnd_development_test");
  Deno.env.set("XENDIT_WEBHOOK_TOKEN", "callback-test-secret");
  Deno.env.set("STORE_JOB_SECRET", "job-test-secret");
  const { createInvoice } = await import("../create-invoice/index.ts");
  const { xenditWebhook } = await import("../xendit-webhook/index.ts");
  const { uploadReviewPhoto } = await import("../upload-review-photo/index.ts");
  const { storeJobs } = await import("../store-jobs/index.ts");
  const id = "12345678-1234-1234-1234-123456789012";
  const order = {
    id,
    user_id: "alice",
    payment_method: "XENDIT",
    payment_status: "PENDING",
    status: "PENDING",
    total_cents: 501550,
    invoice_id: null as string | null,
  };
  const calls: { path: string; body: Record<string, unknown> }[] = [];
  let isAdmin = false, wrongInvoice = false, rejectPublish = false;
  let reviewOwner = "alice", failReviewLookup = false;
  const invoice = () => ({
    id: "invoice-1",
    external_id: wrongInvoice ? "another-order" : id,
    amount: 5015.5,
    currency: "PHP",
    status: "PAID",
    paid_amount: 5015.5,
    invoice_url: "https://invoice-staging.xendit.co/web/invoices/invoice-1",
  });
  globalThis.fetch =
    (async (input: string | URL | Request, init?: RequestInit) => {
      const req = new Request(input, init);
      const path = new URL(req.url).pathname;
      const raw = await req.text();
      const body = raw && !req.headers.get("content-type")?.startsWith("image/")
        ? JSON.parse(raw)
        : {};
      calls.push({ path, body });
      let result: unknown;
      if (path === "/auth/v1/user") {
        result = { id: "alice", email: "demo@example.test" };
      } else if (path.endsWith("/tk_checkout_v2")) result = id;
      else if (path.endsWith("/tk_orders")) result = order;
      else if (path.endsWith("/tk_is_admin")) result = isAdmin;
      else if (path.endsWith("/tk_claim_invoice")) result = true;
      else if (path.endsWith("/tk_attach_invoice")) {
        order.invoice_id = "invoice-1";
        result = null;
      } else if (path.endsWith("/tk_record_payment")) {
        order.payment_status = "PAID";
        result = null;
      } else if (path === "/v2/invoices" && req.method === "GET") result = [];
      else if (path.startsWith("/v2/invoices")) result = invoice();
      else if (path === "/refunds/refund-1") {
        result = {
          id: "refund-1",
          invoice_id: "invoice-1",
          status: "SUCCEEDED",
          currency: "PHP",
          amount: 100,
        };
      } else if (path.endsWith("/tk_confirm_refund")) result = null;
      else if (path.endsWith("/tk_reviews")) {
        // Match the database's column grants: customer tokens cannot select or
        // filter by private review ownership fields, even on their own rows.
        const query = new URL(req.url).searchParams;
        const privateColumn = query.get("select")?.includes("user_id") ||
          query.has("user_id");
        if (
          privateColumn &&
          req.headers.get("authorization") !== "Bearer server-test-key"
        ) {
          return new Response(
            JSON.stringify({
              code: "42501",
              message: "permission denied for table tk_reviews",
            }),
            { status: 403, headers: { "content-type": "application/json" } },
          );
        }
        assert(query.get("id") === `eq.${id}`);
        assert(
          query.get("user_id") === "eq.alice",
          "Use verified user, not a request-body owner",
        );
        assert(
          query.get("select") === "id",
          "Never return private review ownership fields",
        );
        if (failReviewLookup) {
          return new Response(
            JSON.stringify({ code: "57014", message: "query cancelled" }),
            {
              status: 503,
              headers: { "content-type": "application/json" },
            },
          );
        }
        result = reviewOwner === "alice" ? { id } : null;
      } else if (path.endsWith("/tk_reserve_review_image")) {
        result = { id: "photo-1", path: id + "/photo-1" };
      } else if (path.startsWith("/storage/v1/object/review-images/")) {
        result = { Key: "review-images/" + id + "/photo-1" };
      } else if (
        path === "/storage/v1/object/review-images" && req.method === "DELETE"
      ) {
        result = [];
      } else if (path.endsWith("/tk_review_images")) {
        result = req.method === "PATCH" &&
            !(rejectPublish && body.status === "VISIBLE")
          ? { id: "photo-1" }
          : req.method === "PATCH"
          ? null
          : [];
      } else throw new Error(`Unexpected request ${req.method} ${path}`);
      return new Response(JSON.stringify(result), {
        headers: { "content-type": "application/json" },
      });
    }) as typeof fetch;
  const request = (body: unknown) =>
    new Request("https://school.example/function", {
      method: "POST",
      headers: {
        Authorization: "Bearer test-user-token",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  try {
    await t.step(
      "discounted checkout invokes locked Supabase RPC and PHP invoice",
      async () => {
        const response = await createInvoice(
          request({
            action: "create",
            advanced: true,
            items: [],
            delivery: {},
            request_key: id,
            expected_total_cents: 501550,
            voucher_code: "SCHOOL10",
            points: 100,
          }),
        );
        assert(response.status === 200, await response.text());
        assert(
          calls.some((c) =>
            c.path.endsWith("/tk_checkout_v2") &&
            c.body.p_code === "SCHOOL10" && c.body.p_points === 100
          ),
        );
        assert(
          calls.some((c) =>
            c.path === "/v2/invoices" && c.body.currency === "PHP" &&
            c.body.amount === 5015.5
          ),
        );
        assert(calls.some((c) => c.path.endsWith("/tk_record_payment")));
      },
    );
    await t.step(
      "already-paid historical invoices are reverified for receipt recovery",
      async () => {
        calls.length = 0;
        order.payment_status = "PAID";
        const response = await createInvoice(
          request({ action: "resume", order_id: id }),
        );
        assert(response.status === 200);
        assert(calls.some((c) => c.path === "/v2/invoices/invoice-1"));
        assert(calls.some((c) => c.path.endsWith("/tk_record_payment")));
      },
    );
    await t.step(
      "production key rejected before inventory reservation",
      async () => {
        calls.length = 0;
        Deno.env.set("XENDIT_SECRET_KEY", "xnd_production_wrong");
        const response = await createInvoice(
          request({ action: "create", advanced: true }),
        );
        assert(
          response.status === 503 &&
            !calls.some((c) => c.path.includes("checkout")),
        );
        Deno.env.set("XENDIT_SECRET_KEY", "xnd_development_test");
      },
    );
    await t.step(
      "admin read access does not authorize customer payment actions",
      async () => {
        order.user_id = "bob";
        assert(
          (await createInvoice(request({ action: "resume", order_id: id })))
            .status === 403,
        );
        order.user_id = "alice";
      },
    );
    await t.step(
      "refund verification requires admin and authoritative invoice-linked success",
      async () => {
        assert(
          (await createInvoice(
            request({ action: "refund", order_id: id, refund_id: "refund-1" }),
          )).status === 403,
        );
        isAdmin = true;
        assert(
          (await createInvoice(
            request({ action: "refund", order_id: id, refund_id: "refund-1" }),
          )).status === 200,
        );
        assert(
          calls.some((c) =>
            c.path.endsWith("/tk_confirm_refund") && c.body.p_amount === 10000
          ),
        );
      },
    );
    await t.step(
      "forged callback token never queries provider or mutates an order",
      async () => {
        calls.length = 0;
        assert(
          (await xenditWebhook(request({ id: "invoice-1" }))).status === 401,
        );
        assert(calls.length === 0);
      },
    );
    await t.step(
      "callback must match the authoritative order before recording paid",
      async () => {
        calls.length = 0;
        wrongInvoice = true;
        const req = new Request("https://school.example/webhook", {
          method: "POST",
          headers: { "x-callback-token": "callback-test-secret" },
          body: JSON.stringify({ id: "invoice-1" }),
        });
        assert((await xenditWebhook(req)).status === 200); // Unrelated external ID is ignored.
        assert(!calls.some((c) => c.path.endsWith("/tk_record_payment")));
        wrongInvoice = false;
      },
    );
    await t.step(
      "photo upload requires authentication before any review lookup",
      async () => {
        calls.length = 0;
        const response = await uploadReviewPhoto(
          new Request("https://school.example/photo", {
            method: "POST",
            body: JSON.stringify({
              review_id: id,
              bytes_base64: btoa("fake.jpg"),
            }),
          }),
        );
        assert(response.status === 401);
        assert(calls.length === 0);
      },
    );
    await t.step(
      "another customer's review is rejected without reserving or uploading a photo",
      async () => {
        calls.length = 0;
        reviewOwner = "bob";
        try {
          const response = await uploadReviewPhoto(request({
            review_id: id,
            user_id: "bob",
            bytes_base64: btoa("fake.jpg"),
          }));
          assert(response.status === 403);
          assert(
            !calls.some((c) =>
              c.path.includes("tk_reserve_review_image") ||
              c.path.includes("/storage/")
            ),
          );
        } finally {
          reviewOwner = "alice";
        }
      },
    );
    await t.step(
      "review lookup failure is a retryable service error, not a false ownership rejection",
      async () => {
        calls.length = 0;
        failReviewLookup = true;
        try {
          const response = await uploadReviewPhoto(
            request({ review_id: id, bytes_base64: btoa("fake.jpg") }),
          );
          assert(response.status === 503);
          assert(
            (await response.json()).error ===
              "Could not verify your review. Please retry.",
          );
          assert(
            !calls.some((c) =>
              c.path.includes("tk_reserve_review_image") ||
              c.path.includes("/storage/")
            ),
          );
        } finally {
          failReviewLookup = false;
        }
      },
    );
    await t.step(
      "invalid image bytes cannot reserve or upload an image",
      async () => {
        calls.length = 0;
        assert(
          (await uploadReviewPhoto(
            request({ review_id: id, bytes_base64: btoa("fake.jpg") }),
          )).status === 400,
        );
        assert(
          !calls.some((c) =>
            c.path.includes("tk_reserve_review_image") ||
            c.path.includes("/storage/")
          ),
        );
      },
    );
    await t.step(
      "valid photo is reserved, stored privately and published",
      async () => {
        calls.length = 0;
        const bytes = await Deno.readFile(
          new URL("../../../assets/images/adidas-samba.jpg", import.meta.url),
        );
        const response = await uploadReviewPhoto(
          request({
            review_id: id,
            bytes_base64: btoa(String.fromCharCode(...bytes)),
          }),
        );
        assert(response.status === 200, await response.text());
        assert(calls.some((c) =>
          c.path.endsWith("/tk_reserve_review_image") &&
          c.body.p_mime === "image/jpeg"
        ));
        assert(
          calls.some((c) =>
            c.path.startsWith("/storage/v1/object/review-images/")
          ),
        );
        assert(
          calls.some((c) =>
            c.path.endsWith("/tk_review_images") && c.body.status === "VISIBLE"
          ),
        );
      },
    );
    await t.step(
      "a failed photo publication releases its slot and deletes the private object",
      async () => {
        calls.length = 0;
        rejectPublish = true;
        const bytes = await Deno.readFile(
          new URL("../../../assets/images/adidas-samba.jpg", import.meta.url),
        );
        const response = await uploadReviewPhoto(request({
          review_id: id,
          bytes_base64: btoa(String.fromCharCode(...bytes)),
        }));
        assert(response.status === 503, await response.text());
        assert(
          calls.some((c) =>
            c.path.endsWith("/tk_review_images") && c.body.status === "REMOVED"
          ),
        );
        assert(
          calls.some((c) =>
            c.path === "/storage/v1/object/review-images" &&
            Array.isArray(c.body.prefixes)
          ),
        );
        rejectPublish = false;
      },
    );
    await t.step("job endpoint requires its private secret", async () => {
      calls.length = 0;
      assert((await storeJobs(request({}))).status === 401);
      assert(calls.length === 0);
    });
  } finally {
    globalThis.fetch = saved;
    vars.forEach((key, index) =>
      before[index] === undefined
        ? Deno.env.delete(key)
        : Deno.env.set(key, before[index]!)
    );
  }
});
