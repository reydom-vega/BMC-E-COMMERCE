# Review ownership and empty-photo layout correction - October 25, 2026

The phone's new ownership error exposed a permission mismatch in the earlier photo function: customer tokens cannot select `tk_reviews.user_id`. The handler queried that column using the customer client, then treated the permission failure as a non-owner review. A permission-aware mock reproduced the exact false 403 before the correction. The previous mock had allowed the private column.

The corrected function verifies the login first and uses its existing server-only service-role client to select only the review ID, filtered by the requested review and the verified user's ID. Query failures produce 503; non-owner/missing reviews produce 403. It grants no new customer privileges. Regenerated `docs/deploy/upload-review-photo.ts` includes this correction. Deploy that updated file; no new migration or secret is required.

The requested UI correction removes `No photos yet.` and the fixed photo-section height. An empty product-review photo section now measures zero height; published photos still show thumbnails/report actions and owners retain Add photo.

Executed checks:

- Nine targeted Flutter review/photo tests passed, including zero-height empty photo sections and restored photo content after upload. The earlier complete suite passed 63 tests; this follow-up ran the affected nine tests.
- Native disposable PostgreSQL: all 22 groups and concurrency races passed. New assertions reproduce customer SELECT/filter rejection with code `42501`, then verify the service-role query returns only the matching owner's review.
- Edge tests: seven tests / 14 handler steps passed. The mock now enforces private-column permissions and checks use of the verified user's ID, including a forged body `user_id`, missing authentication, wrong-owner rejection before reservation/storage, lookup failures, successful private upload/publication and failure cleanup.
- All four generated Dashboard functions passed Deno type checking. No hosted function, database or private user account was changed from this session.
- Flutter analyzer: no issues. Debug APK build passed in 49.5 seconds and its v2 signature verified. The latest `build/app/outputs/flutter-apk/app-debug.apk` was built **2026-10-25 02:45:23 Asia/Taipei**, **196,680,532 bytes**, with `ADVANCED_SHOPPING=true` and the existing public cloud/Firebase config. No Dart source is newer than the APK. SHA-256: `33788536B5DD23EDB1ADFEDFE04F7C5130F7406149D0F5BCEF1440B224C9AAE1`.

Install the newest debug APK for the layout update and redeploy `upload-review-photo` for the ownership correction. A signed-in upload on the user's phone remains unverified until that function is deployed.

---

# Review and photo fixes - October 25, 2026

Reproduced the old review dialog's failure with a focused input: its controller was disposed before the route exit animation finished. The regression initially failed with `A TextEditingController was used after being disposed`. A dedicated stateful dialog now owns controller/focus disposal. Product details use refreshed catalog ratings and reload reviews/photos after saves, edits or photo changes; pull to refresh is available.

Photo uploads now prepare bounded JPEGs off the Android UI isolate, preserve previews on failure, show controlled Edge Function errors and support retry. The server uses pinned JavaScript JPEG/PNG decoders and re-encodes fresh pixels without metadata, replacing the separate WASM runtime asset absent from Dashboard paste deployments. Authentication, delivered-purchase ownership, three-photo reservation and private Storage remain in place. Publication failures remove the object and release the reservation.

Executed checks:

- Analyzer: no issues. Node tooling/runtime directories are excluded from Dart analysis.
- Full Flutter suite with `ADVANCED_SHOPPING=true`: **63 passed**, two optional preview tests skipped. Nine new tests cover focused cancel/save/back, keyboard layout, failed-save retry and duplicate prevention, editing an existing review, refreshed product rating/text/photo visibility, PNG/WebP-to-JPEG conversion and invalid inputs, actual FunctionsClient error bodies, and repeated photo-upload attempts after an error.
- Disposable native PostgreSQL: all 22 migration/security/lifecycle groups and the separate-connection concurrency races passed. Added public-column reads as another shopper and a guest to verify edited review visibility and unchanged count. No database schema change is needed for these fixes.
- Edge tests: **7 tests / 11 handler steps passed**, including real JPEG/PNG decode/re-encode, metadata stripping, invalid-byte rejection, valid photo reservation/private upload/publication and cleanup after publication failure. All four generated Dashboard function copies passed Deno type checking.
- Read-only hosted public REST checks: three recently reviewed products had matching stored review counts and average ratings. No review contents/identities were printed and no cloud records were written. An unauthenticated photo-endpoint probe returned the expected 401 from the handler, confirming the function is deployed; it does not verify an authenticated upload.
- Android debug build passed in 42.5 seconds with the existing ignored public cloud/Firebase config and `ADVANCED_SHOPPING=true`. APK v2 signature verified; packaged Firebase installation-ID opt-in remains true. No Dart file is newer than the APK. ADB reports no connected device.

Latest APK: `build/app/outputs/flutter-apk/app-debug.apk`, built **2026-10-25 02:29:56 Asia/Taipei**, **196,680,673 bytes**. SHA-256: `0EF8C495342B0202FB66B4CA477D33CABEABA1C013BF83CAE07D1D1869268C2D`. The existing Firebase Kotlin migration warning did not prevent the build.

Required hosted step: replace the existing `upload-review-photo` function with [its regenerated Dashboard copy](deploy/upload-review-photo.ts), deploy, then install this APK and retry on the phone. No new migration, secret, website or hosting service is required for this follow-up. This session did not deploy the function or perform a signed-in cloud/physical-phone photo upload. [Instructions](BUGFIXES_20261025.md) describe the remaining phone check. Earlier validation entries below are historical.

---

# Push registration follow-up - October 25, 2026

The reported phone error occurred inside FirebasePushDevice.register before token/preference persistence. Inspection found Firebase Messaging 17 register() was called without the Android firebase_messaging_installation_id_enabled=true metadata flag. The Android SDK explicitly requires this opt-in and throws without it. With FID mode enabled, the old getToken() fallback is incompatible and also throws; it has been removed.

Changed AndroidManifest.xml, lib/services/push_device.dart and push_service.dart. Registration now subscribes first, waits for both the native registration task and onRegistered callback in either order, bounds the wait to 30 seconds and cancels the listener on success/failure/timeout. Error messages distinguish missing manifest settings, Google Play services, Firebase configuration rejection and network/timeout failures without printing credentials or identifiers. Existing Supabase/Firebase secrets and database schema are unchanged.

Local Android Firebase file and imported public defines match, including package, app ID and sender ID. No client service-account/private key was found. Twelve targeted push tests passed, including new low-level SDK adapter tests. Full Flutter suite: 54 passed, two optional screenshot tests skipped. Analyzer: no issues. ADB has no connected device, so physical phone registration and delivery still require retesting after installing the rebuilt APK.

Primary SDK reference: https://firebase.google.com/docs/reference/android/com/google/firebase/messaging/FirebaseMessaging#register()

Corrected debug APK built successfully at 01:41 on October 25 (Asia/Taipei), 196,671,560 bytes. APK Signature Scheme v2 verification passed. Inspection of the packaged AndroidManifest.xml confirmed firebase_messaging_installation_id_enabled is true. No Dart source is newer than this APK. SHA-256: C769627C41B905908DD34FE0C95FB372D5EFD57A55D18A3EE1C68845653FC8F1. Install build/app/outputs/flutter-apk/app-debug.apk over the existing demo app and retry enabling push. No SQL migration or Supabase function redeployment is required for this client-side correction.

---
# Validation - October 25, 2026 (UI and functionality fixes)

Implemented automatic independent voucher/rewards quoting, reactive checkout totals, the themed Rewards cards, an owned-order PDF viewer with save/share, atomic push preference/device registration, and removal of courier tracking UI. Existing basic order statuses and historical tracking/payment/customer records are preserved.

Executed checks:

- flutter pub get: passed. Dependencies resolved without adding a new package.
- flutter analyze: passed with no issues.
- Full Flutter suite with ADVANCED_SHOPPING=true, preview and document capture: 50 tests passed. This covers voucher debounce/clearing, rewards-only and combined redemption, insufficient points, expired vouchers, stale response isolation, reward switch/amount changes, quantity/shipping changes, paid/unpaid document separation, real PDF generation/viewer/save/share plumbing, ownership/snapshot rejection, persisted push settings and permission/token/database failures, and admin status actions without tracking.
- Disposable native PostgreSQL: all 22 migration/security/lifecycle groups passed, plus real concurrent voucher-limit/points-spending races. The new migration was applied and repeat-tested for atomic push preference/token changes, guest rejection, device deactivation and duplicate-safe repair of legacy collected COD receipts. No hosted records were changed.
- Deno Edge tests: 7 tests with 9 handler steps passed, including re-verification of already-paid historical invoices for missing receipts, PHP invoice totals, sandbox keys, ownership/refund/callback checks and image validation. All four generated Dashboard copies type-checked.
- Refreshed phone Rewards/checkout screenshots were inspected visually. Sample confirmation and receipt PDFs were regenerated, rendered and visually checked; paid status and confirmation-only disclaimer remain distinct.
- Active Flutter source was searched: no courier/shipment panel, tracking query, courier name/number or tracking editor remains. The historical SQL tables/functions are intentionally retained.
- ADB reported no connected devices. Actual Android PDF rendering/system save dialog, Xendit sandbox merchant transactions and FCM device delivery were not exercised.

The local build configuration has no public Firebase FCM values and no Android google-services.json. Real push delivery cannot be verified/enabled until the user supplies the matching Android Firebase config, rebuilds, configures the server service account and runs the cloud worker. Missing/denied/failed configuration is never shown as successful push enablement; in-app notifications remain available.

Hosted setup: apply only supabase/migrations/202610250001_checkout_documents_push.sql if all earlier migrations are installed, and redeploy create-invoice from its updated source or generated Dashboard copy. No hosted migrations, function updates or notification secrets were applied by this session. Full setup and changed-file map: [October 25 fix notes](BUGFIXES_20261025.md).

Android debug build passed with the existing public Supabase configuration and ADVANCED_SHOPPING=true. Output: build/app/outputs/flutter-apk/app-debug.apk, built October 25 at 00:54 (Asia/Taipei), 170,461,185 bytes. APK Signature Scheme v2 verification passed; minimum API 24, target API 36; Internet and POST_NOTIFICATIONS permissions are present. No Dart source is newer than the APK. No .env, local.json or Firebase service-account file is packaged. SHA-256: A47F39AC37936B9402C8DD530D2FE71FCA67387EE7E09958F2B62D8FA9F82ED5. Existing Kotlin plugin/SDK XML compatibility warnings did not prevent this build. The earlier October 24 release APK is historical; use this updated debug APK for the fixes.

---
# Validation - October 24, 2026 (Android school scope)

The current implementation targets the existing Flutter Android app and Supabase cloud backend. No website was deployed. PHP hosting/payment-service dependencies were removed from Flutter; the superseded PHP draft was moved into the ignored local tools/runtime/superseded-php-reference archive. Xendit function names and callback address are preserved, payments require test keys, and all financial calculations use Philippine Pesos.

Executed local checks:

- Flutter analyzer: no issues.
- Full Flutter suite with ADVANCED_SHOPPING=true and preview capture: all 36 tests passed. This includes vouchers, addresses, restock, rewards/tracking, support, notification preferences, receipt availability, analytics filters, account isolation, original storefront/themes/wishlist and direct payment navigation.
- Native disposable PostgreSQL: all 21 migration/RLS/financial lifecycle groups passed, plus separate-connection concurrent voucher limit and points double-spend races. Failed transactions preserved stock. The original four and five additive migrations all executed successfully. No cloud database was modified.
- Deno: 7 tests and 8 handler steps passed, covering invoice matching, allowed checkout URLs, callback tokens, test-key enforcement, advanced Supabase checkout, ownership, admin refund verification, forged/unrelated callbacks, real JPG/PNG/WebP decode/re-encode, invalid image bytes and private job authentication. Provider HTTP was mocked; this was not a Xendit merchant transaction.
- Four generated Dashboard function copies passed Deno type checking. Their canonical source is under supabase/functions; _shared is not a function.
- Current README/setup/source-map links were checked, and active Android checkout/photo/config source contains no PHP service dependency.
- The refreshed checkout preview was visually inspected; earlier branded sample confirmation, payment receipt and sales report PDFs were also rendered/inspected. Sample documents are fixtures, not real payments.

Android release build passed with the existing public cloud configuration and ADVANCED_SHOPPING=true. The APK is build/app/outputs/flutter-apk/app-release.apk, 73,732,183 bytes (70.3 MB), Android minimum API 24, target API 36. APK Signature Scheme v2 verification passed with the existing development signer. SHA-256: ED2FB0FC2364CF5F97BCBBCADEF192E2B368D87DC30D0AFED77A71F8F47C237F. The Firebase plugin emitted a future Kotlin Gradle migration warning; the current build succeeded.

Remaining external checks: apply the five new migrations to the existing cloud project, redeploy the existing two functions and create upload-review-photo/store-jobs, confirm hosted email settings and sandbox secrets/callbacks, install on a physical Android phone, and exercise real sandbox payment/refund/photo workflows. Optional Firebase device delivery was not tested/configured; persistent in-app notifications remain the fallback. No hosted function deployment, Auth setting change or physical-device installation was performed by this session. The APK must be paired with the documented upgraded backend before demonstrating advanced features.

See [current Android setup](ADVANCED_SETUP.md). Historical validation entries below describe earlier app revisions.

---
# Validation — October 21, 2026

## Shopping and appearance update — October 23, 2026

Added brand size guides, private account/device guest wishlists, combined catalog filters, editable category/fit notes, and persistent system/light/dark appearance. Screen colors now follow the active theme across the store, checkout and administration while retaining the supplied logo palette and unchanged product photographs.

`flutter analyze --no-pub` passed with no issues. All 21 tests passed with `CAPTURE_PREVIEWS=true`, including phone and desktop rendering. Coverage includes matching size/color on one in-stock variant, inclusive price limits, chart distinctions, remembered appearance, separate guest/account wishlists, stale account-response isolation, failed-save handling, and the customer flow through saving/removing a pair, size guidance, price validation, applying filters and switching themes.

The PostgreSQL regression suite passed all 13 groups, applying all four migrations in a disposable database. The new checks cover wishlist ownership/privacy, duplicate saves, guest restrictions, denial of archived-product saves, category/fit-note validation and preservation of metadata when older clients omit those fields.

Light/dark screenshots for home, collection, filters, wishlist, product, size guide and sign-in are in `previews/` at 390 and 1280 pixels wide. Visual inspection found a chip font-resolution issue, which was fixed and covered by an additional font assertion before regenerating the previews. The reference charts were checked against the official Nike/adidas/Puma pages linked in the README; this is a men's US 6–12 quick guide rather than women's/kids' sizing support.

The new hosted migration `202610230001_shopping_features.sql` was not applied to the user's project in this session. Apply that file once in Supabase SQL Editor if the original three migrations are already installed. No Edge Function redeployment is required. The existing Xendit business logic was not changed.

The Android release APK and web build both passed using `--dart-define-from-file=config/local.json` (public Supabase configuration). APK signature verification passed with the existing development signing key. The APK is 66,033,270 bytes; the original logo is unchanged and packaged, and neither server `.env` nor `config/local.json` is bundled as a file. The web output contains the new wishlist, size guide, filters and appearance preference. No physical-device install or hosted account/payment tests were performed for this update.

## Registration update — October 23, 2026

Registration now expects immediate Supabase sign-in without email confirmation. The confirmation-email prompt was removed, and the local `[auth.email]` configuration sets `enable_confirmations = false`. Email format and password validation remain in place; mailbox access is not required. A signup response without a session is reported as incomplete instead of treating the user as signed in.

Three registration regression tests passed using a fake Auth service: immediate sign-in with a session, rejecting a user-only response as unauthenticated, and closing the registration form without an email-confirmation step. The full widget suite passed with 13 tests and 2 optional screenshot tests skipped. The analyzer passed with no issues. No hosted users were created for these checks.

The hosted **Confirm email** setting was not modified: this session has no connected dashboard browser. A read-only request to the configured Auth settings endpoint also timed out, so the current hosted value was not verified. Turn **Confirm email OFF** under Authentication → Sign In / Providers in the Supabase dashboard, then save. Local config changes alone do not update hosted Auth.

## Payment navigation update — October 23, 2026

The order's **Continue to payment** action now opens Xendit directly. New online checkouts also open their prepared invoice automatically. Web checkout uses the current browser tab to avoid popup blocking after asynchronous invoice creation; mobile checkout retains its embedded payment page. An external launch failure leaves the saved order available for retry.

Five navigation regression tests cover a delayed invoice response, automatic opening only once for a new order, failed-launch retry without creating another order, skipping payment when the provider reports it already paid, and rejecting an untrusted invoice URL. These tests use a fake invoice service and URL launcher; they do not create Xendit transactions.

`flutter analyze --no-pub` passed with no issues. The full widget suite passed: 10 tests, with the 2 optional screenshot tests skipped. All 5 navigation tests also passed in headless Chrome. The Windows Flutter test server initially returned 404 for its CanvasKit resources; temporary copies from the installed SDK were served under the test directory for that run, then removed. No SDK or application rendering configuration was changed.

## Branding update — October 22, 2026

The supplied `assets/images/TrendKicks-Logo.png` is now the source for in-app logos, launcher icons, splash screens and browser icons. The original file is preserved. The shared theme uses the logo's lime (`#BEFA1E`), black, white and silver palette, with darker lime text for readability on light surfaces.

`flutter analyze --no-pub` passed with no issues. All 7 tests passed with `CAPTURE_PREVIEWS=true`, including phone and desktop rendering. Updated home, collection, product and account sign-in screenshots are in `previews/`. The Android release preview rebuilt successfully and its APK signature verified; the bundled assets include the original and all three layout-specific logo copies. The web build also passed, with the new logo loader, black manifest theme and PNG browser icons. Local HTTP checks for the page, favicon, app icon, logo and compiled JavaScript returned 200. iOS/macOS/Windows icon assets were regenerated, but those platform builds were not run.

## Completed locally

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | Passed, no issues |
| `flutter test --no-pub` | Passed, 5 tests; 2 optional rendering tests skipped |
| `flutter test --no-pub --dart-define=CAPTURE_PREVIEWS=true` | Passed, 7 tests including phone/desktop rendering |
| `npm --prefix tools test` | Passed, 12 database regression groups |
| Deno check of both Edge Function entrypoints | Passed |
| Deno payment-rule tests | Passed, 4 tests |
| `flutter build web --no-pub --no-wasm-dry-run` | Passed |
| `flutter build apk --release --no-pub` | Passed; universal preview APK, approximately 59.4 MB |
| APK signature verification | Passed with development signing key |
| Local preview HTTP checks | Page, bootstrap, compiled JavaScript, font and font-license requests returned 200 |

Visual checks used rendered Flutter widgets at 390×1000 and 1280×1000. The flow tests also exercised search, product opening, size selection, adding to the bag and viewing the bag at 360 and 1200 pixels wide. Screenshots are in `previews/`.

The initial checks found and fixed phone cart-total and desktop banner overflows. An asynchronous refresh now checks widget lifetime, including when an account change removes the originating screen while a navigation callback is outstanding.

Database checks run against disposable embedded PostgreSQL (PGlite), with mock Supabase-owned Auth/Storage schemas. They execute the actual migrations and database functions. Coverage includes customer isolation, privilege escalation denial, cart stock checks, authoritative pricing/shipping, changed-total rejection, checkout idempotency, multi-item transaction rollback, cancellation/restocking, fulfillment transitions, delivered-purchase review eligibility/editing, aggregate ratings, item refunds, notifications, payment privileges, invoice leases, duplicate/stale events, expiration/late-payment handling, abandoned reservations, admin product/variant boundaries and storage upload policies.

The Xendit tests reject wrong order IDs, invoice IDs, amount/currency mismatches, underpayments, spoofed hosts and invalid callback tokens. They do not invoke a real payment provider or prove that a hosted webhook configuration works.

## Not performed in this session

- Applying migrations or deploying functions to the user's hosted Supabase project.
- Creating real accounts, uploading real product images, or granting a hosted admin role.
- Real Xendit test/live payments, callbacks, channel activation, settlement or refunds.
- Installing/running the APK on a physical Android device or testing wallet-app redirects.
- Production keystore signing, app-store publication or production load/concurrency testing.
- Figma comparison: no design references were supplied.

The October 21 APK and web builds used catalog-preview mode. See the latest update above for current build configuration. Optional Android shrinking is disabled for this development machine, and the APK uses the starter development signing configuration.
