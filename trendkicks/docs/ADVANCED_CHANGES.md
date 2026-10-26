# Advanced implementation map

The [Android school scope](ADVANCED_SETUP.md) overrides PHP migration/hosting requirements. Required backend: the existing cloud Supabase only. No website was deployed.

The [October 25 fix log](BUGFIXES_20261025.md) lists the latest pricing controller, document viewer, push permission/registration changes and removed tracking UI. Apply the new `202610250001_checkout_documents_push.sql` after the earlier migrations.

## Flutter

- `lib/config/app_config.dart`: public Supabase values and staged advanced flag; no PHP origin.
- `lib/services/payment_service.dart`: Supabase Edge create/resume/cancel/refund verification; locked database checkout for COD.
- `lib/services/shopping_service.dart`: addresses, quotes, rewards and receipts.
- `lib/services/order_documents.dart`: branded historical confirmation/verified receipt PDFs.
- `lib/services/push_service.dart`: optional Android FCM, in-app fallback, token lifecycle, owner-checked/deduplicated navigation.
- `lib/models/fit_recommendation.dart`, `lib/providers/compare_controller.dart`: deterministic measurement rules and maximum-three comparison.
- Screens/components: address book, rewards, fit finder, comparison, restock, review photos, support, notification preferences, admin tools and sales reports. Existing Account/Checkout/Product/Orders/Notifications/Admin integrate them through the preserved UI/navigation.
- Android Internet/notification permissions; original ID/logo/classroom signing retained. Firebase is optional push transport only.

## Supabase

Original four migrations preserved. Five dated `20261024` add financial reservations/discounts/immutable rewards/receipts, addresses/vouchers, restock/shipments/support/preferences/private tokens/outbox, private photo reviews/moderation, guarded sales reporting/refund settlement and operational hardening.

- `create-invoice/index.ts`: existing checkout enhanced for discounts and admin verified refunds; create/resume/cancel compatibility retained.
- `xendit-webhook/index.ts`: same callback address, token/provider verification, recorded payment events/receipts and refund reconciliation.
- `_shared/runtime.ts`, `payment_rules.ts`: Auth, sandbox-key guard, matching PHP currency/order/invoice totals and verified financial recording.
- `upload-review-photo/index.ts`, `_shared/review_image.ts`: bounded authenticated requests, review ownership/count reservation, pure JavaScript JPEG/PNG decode/re-encode and private Storage upload. Android normalizes JPG/PNG/WebP to JPEG off the UI isolate; Dashboard deployment needs no separate WASM file.
- `store-jobs/index.ts`, `_shared/push_delivery.ts`: private cloud media cleanup and optional leased FCM delivery with OAuth.
- `docs/deploy/*.ts`: generated self-contained Dashboard copies; `_shared` is not a function.

The earlier PHP draft is excluded from the application. No separate host or payment-service URL is required.

## Verification

- `test/advanced_features_test.dart`: fit/comparison/dates/address/phone layout/PDF generation.
- `test/advanced_flows_test.dart`: actual screens/services with mocked Supabase HTTP for vouchers, addresses, restock, rewards, support, preferences, receipt availability and analytics filters.
- `test/push_navigation_test.dart`: owner isolation and routing.
- `_shared/payment_rules_test.ts`, `cloud_flows_test.ts`: provider/ownership/refund/callback/test-key guards and real image decode/invalid-byte rejection.
- `tools/database_test.mjs`, `tools/real_database_test.mjs`: all migrations, RLS, financial lifecycle and separate-connection voucher/points races with stock rollback.
- `output/pdf`: visually inspected sample confirmation/receipt/report artifacts, not real payments.

See [validation](VALIDATION.md) for executed checks and external limitations.
