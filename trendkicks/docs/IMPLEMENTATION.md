# Current scope - Android school project (October 24, 2026)

The latest user instructions override PHP migration, paid/commercial hosting and website deployment directions in the original reference prompt. Required stack: existing Flutter Android app, cloud Supabase and Xendit sandbox in PHP currency. No PHP backend, website, domain or paid courier service is required. Preserve branding/navigation; support internet-connected phones and classroom APK installation. Use in-app notifications and manual courier management when optional services are absent.

See [current setup](ADVANCED_SETUP.md), [source map](ADVANCED_CHANGES.md) and [validation](VALIDATION.md). Historical notes below describe earlier work and must be read subject to this scope.

# Implementation decisions and remaining work

The files in `reference/` are unmodified copies from the supplied ZIP. The user explicitly selected Flutter, Dart, Supabase, and Xendit. That decision replaces Firebase/Firestore/Storage references in those files. Original document instructions are requirements input; they do not grant access to external accounts or require executing embedded commands.

## Adaptation

| Original specification | Implementation |
| --- | --- |
| Firebase Authentication | Supabase Auth email/password, immediate sign-in without email confirmation |
| Firestore collections | PostgreSQL tables, all prefixed `tk_` |
| Firebase security rules | Row level security, column grants, guarded database functions |
| Firebase transactions | PostgreSQL transactions and row locks |
| Firebase Storage | Supabase `product-images` bucket with admin upload policy |
| Provider | Feature controllers using Provider/ChangeNotifier |
| GCash / Maya pending details | Xendit hosted invoices; channels depend on the merchant account |
| Customer-specific cart | Supabase cart scoped to the authenticated user |
| Initial catalog | Eight seeded shoes and bundled illustrative shoe photographs |
| In-app notifications | Database-generated order/refund events; no push dependency |

`tk_` tables avoid overwriting the existing prototype's `products` and `orders` tables or guessing their deployed schema. They are not an automatic migration of historical prototype orders. Audit and retire the old tables/functions after the new app is validated, especially any old public order-access policy.

## Document conflicts resolved

* `01_Requirements.md` permits authenticated users to review without purchasing. `03_Features.md` and `07_Security.md` require a delivered purchase. The implementation follows the latter: one editable review per delivered order item, validated in the database.
* Some documents say single brand while explicitly listing Nike, Puma, and Adidas. The implementation is one store operated by one administrator, carrying multiple product brands. There are no sellers or marketplace flows.
* Refund eligibility was not fully defined. This implementation accepts item-specific requests after delivery, one request per item. Cancellation is available before shipping. Approved refunds are review decisions; actual fund return remains a separate merchant action.
* No Figma screenshots or `design/` folder were supplied. The supplied TrendKicks logo now governs the branding and both light/dark palettes. Exact Figma matching remains pending the actual references.
* The documents reference missing/renamed files such as `08_ASSETS.md`. These are not silently treated as supplied assets or requirements.

## Implemented flows

* Catalog, partial search, dynamic brand chips, rating and price sorts, galleries, stock-aware size/color selection and quantity.
* Category, available size/colorway, inclusive PHP price-range and in-stock filters compose with search, brand and sorting. A size/color match must be on the same available variant. Filter drafts can be cancelled, reset or applied; active filters have removable chips.
* Nike/adidas/Puma men's US 6–12 size-reference charts, measuring steps, official source links and optional admin-entered model fit notes. Nike CM/JP label values are distinct from adidas measured foot length; unsupported brands do not receive guessed conversions. Categories and fit notes are persisted through the existing guarded admin product RPC.
* Account-private Supabase wishlists with add/remove hearts on cards and product details, plus a separate device-persistent guest wishlist. Signing in/out switches lists without merging or exposing another account's saved products. Archived/missing catalog entries can be removed from the wishlist.
* System, light and dark appearance with a device-persistent preference. Header toggle and signed-out/account appearance controls are available; customer, checkout and admin screens use the active palette while product photographs and logos keep their original colors.
* Supabase sign-up/sign-in/sign-out with email confirmation disabled, immediate sign-in on registration, and editable name/phone/address. Email format is validated without requiring a working mailbox. Browsing works without signing in. Disable **Confirm email** in the hosted project's Authentication settings; the local configuration alone does not change hosted Auth. The app requires a real session before treating registration as signed in.
* Account carts persist in PostgreSQL. Guest preview bags stay in memory and are cleared when switching into an account; guest selections are not silently merged into another person's saved cart.
* Checkout includes recipient, phone, delivery address, shipping, COD or Xendit. Backend prices and shipping override client inputs; a changed displayed total is rejected for review.
* Stable checkout request IDs prevent duplicate orders on retry. Transactions snapshot products/prices/variants and reserve inventory atomically. Cart purchase quantities are deducted in the same transaction.
* Online payments use backend-generated invoices and verified callbacks, with a server-side check for payment status. The client never marks an order paid. Duplicate and stale callbacks do not duplicate notifications or downgrade a paid order.
* Pre-shipping cancellation returns stock once. Late payments for cancelled orders become `REFUND_REQUIRED`, with a customer notification.
* Orders show confirmation, separate payment/delivery status, tracking stages, shipping details, items and prices. Admin fulfillment must advance one stage at a time and cannot fulfill unpaid online orders.
* Delivered purchases support editable reviews and item refunds. Product ratings are calculated from real reviews.
* Admin overview, product create/edit/archive, image uploads, variant inventory, fulfillment, refund review. Admin membership is private and cannot be self-assigned from Flutter.

## What still needs configuration or evidence

1. Apply migrations and deploy functions to a Supabase project. Local database tests execute against disposable PostgreSQL; they do not demonstrate your hosted configuration or network callbacks.
2. Add Xendit **test** credentials, callback token and invoice callback URL. Confirm which GCash/Maya channels your merchant account enables, then complete the test scenarios in the README. No payment has been charged by this development session.
3. Configure the abandoned-reservation cleanup schedule. Invoice expirations normally arrive via Xendit; alert on failed callbacks and reconcile missed events operationally.
4. Choose the store's actual delivery fee (sample: PHP 120), product pricing, inventory, accurate product photographs, contact details, refund/return terms and delivery service. Sample catalog photos are illustrative and are not guaranteed to depict the named shoe model or selected color.
5. Supply Figma references for visual matching, and configure the Android package name, launcher artwork, upload keystore and release signing before publishing to an app store. The starter application ID is retained.
6. Validate authentication, storage policies, two-user isolation and Xendit scenarios against a separate test project. Load/concurrency testing, provider outages, real-device wallet redirects and live settlement/refund processing require that environment.

## Recommended next improvements

Prioritize deployment and the end-to-end checklist over adding features. Apply the fourth migration, `202610230001_shopping_features.sql`, for account wishlists and catalog metadata. After that: password recovery/email changes with verified deep links, pagination for large admin datasets, operational payment reconciliation, image cleanup for abandoned uploads, accessible large-text testing on physical phones, and women's/kids' size-chart support with explicit product sizing metadata. Phone push, revenue charts, GPS tracking, discounts and multi-vendor features are outside the current scope.

## Architecture

`screens → providers → services → Supabase`

* `models/`: typed products/variants, cart lines, profiles, orders.
* `providers/`: catalog, auth and cart state; widgets do not store credentials or assign privileges.
* `services/`: Supabase queries/RPCs, image uploads and payment function calls.
* `core/`: theme, shared UI and user-facing errors.
* `data/`: preview catalog only; it cannot create real orders.
* `supabase/migrations/`: schema, RLS, trusted business operations, seed catalog and cleanup.
* `supabase/functions/`: authenticated invoice orchestration and authenticated provider callback processing.

Prices are integer centavos everywhere except at the Xendit API boundary (PHP decimal). Orders preserve snapshots. Product deletion is archival so past orders and reviews remain meaningful.
