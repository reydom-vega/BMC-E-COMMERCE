> October 25 update: vouchers and rewards now apply automatically through server quotes; paid receipts and confirmations open an in-app PDF viewer. Courier tracking has been removed from customer/admin UI while basic order statuses and historical data are preserved. See [bug-fix setup and validation](BUGFIXES_20261025.md) for Firebase configuration and the new migration.

# Android school demonstration setup

Required stack: **Flutter Android + existing cloud Supabase + Xendit sandbox in Philippine Pesos (PHP)**. No PHP server, public website, paid hosting, custom domain or ngrok tunnel is required. This school scope overrides the original prompt's commercial/PHP migration requirements.

## 1. Apply missing database migrations

If the original four migrations are installed, run these advanced migrations **once each, in order** in the existing project's SQL Editor:

1. `supabase/migrations/202610240001_financial_foundation.sql`
2. `supabase/migrations/202610240002_customer_operations.sql`
3. `supabase/migrations/202610240003_review_media.sql`
4. `supabase/migrations/202610240004_admin_reporting.sql`
5. `supabase/migrations/202610240005_operational_hardening.sql`
6. `supabase/migrations/202610250001_checkout_documents_push.sql`

A fresh project must first apply `202610210001_store.sql`, `202610210002_catalog.sql`, `202610210003_reservation_cleanup.sql`, and `202610230001_shopping_features.sql`. The original files are preserved. Do not reset the database or rerun installed CREATE TABLE migrations. CLI users can use `supabase db push` after linking/checking the correct project's migration history.

If the October 24 migrations are already installed, apply only the October 25 migration. It adds atomic push preference/token registration and safely fills missing receipts for legacy admin-collected COD orders.

The additions use real tables, owner/admin RLS, restricted financial RPCs, immutable rewards/receipts and private `review-images` Storage. Customers cannot edit balances/payment status or query private analytics. The original checkout stock reservation runs inside the new checkout transaction. The baseline migration seeds eight sample sneakers for demonstrations.

## 2. Authentication and administrator

Keep email/password enabled. Turn **Confirm email OFF** in the hosted Email provider settings for the requested school signup flow. A valid email format is required, but mailbox access is not. Local `supabase/config.toml` alone does not update hosted Auth. Signup must return a signed-in session.

Register a test account, get its UUID from Authentication > Users, and run in SQL Editor:

```sql
insert into public.tk_admins(user_id)
values ('REPLACE_WITH_YOUR_AUTH_USER_UUID') on conflict do nothing;
```

Sign out/in to reload the role. Customer metadata cannot grant admin rights. The dashboard's localhost Site URL is an email redirect setting, not the cloud Auth server location. With confirmation disabled, no website/domain is needed for signup; future password-reset/confirmation links would require separate Android deep-link setup.

## 3. Deploy four cloud Edge Functions

| Function | Purpose | Handler authentication |
|---|---|---|
| `create-invoice` | Existing create/resume/cancel plus advanced checkout and refund verification | Supabase token; owner for payment actions; admin for refunds |
| `xendit-webhook` | Existing invoice callback and successful refund reconciliation | Callback token followed by authoritative Xendit API check |
| `upload-review-photo` | Validated photos for owned delivered-purchase reviews | Supabase token and review/purchase ownership |
| `store-jobs` | Media cleanup and optional queued FCM delivery | Private `x-store-job-secret` |

**`_shared` is a source folder, not another function.** Preserve the existing payment function names and callback URL. Dashboard users can paste the matching self-contained files in [deploy](deploy/README.md). CLI alternative:

```powershell
supabase functions deploy create-invoice --no-verify-jwt
supabase functions deploy xendit-webhook --no-verify-jwt
supabase functions deploy upload-review-photo --no-verify-jwt
supabase functions deploy store-jobs --no-verify-jwt
```

Gateway JWT checks are disabled because each handler authenticates its appropriate caller. Apply the new migrations before updating functions: verified invoices now use `tk_record_payment` for events/receipts.

For the October 25 review/photo follow-up, redeploy only the updated `upload-review-photo` if the other setup is already installed; no additional migration or secret is required. The generated Dashboard copy includes all image-processing code and needs no separate WASM asset. Android converts JPG/PNG/WebP to a resized JPEG; the server independently validates JPEG/PNG pixels and strips metadata. See [review/photo fixes](BUGFIXES_20261025.md).

The latest copy also corrects false ownership rejection: review ownership is checked server-side against the verified user, since customer tokens cannot read the private `tk_reviews.user_id` column. Do not grant customer access to private columns to work around this error; deploy the corrected function.

Set these in **Supabase Edge Functions > Secrets**:

- `XENDIT_SECRET_KEY`: existing **test** secret (`xnd_development_...`). Live keys are rejected before reservations/provider calls.
- `XENDIT_WEBHOOK_TOKEN`: Xendit's callback verification token.
- `XENDIT_PAYMENT_METHODS`: optional comma-separated enabled sandbox channels; empty uses account defaults.
- `STORE_JOB_SECRET`: random private secret for the cloud job.
- `FCM_SERVICE_ACCOUNT_JSON`: optional service-account JSON on one line, server-side only; omit for in-app notifications alone.

Supabase supplies the server URL, anon and service-role keys. Never put secret keys/tokens in Flutter. `.env.example` has placeholders for optional local function development; the installed phone needs only the cloud backend.

In **Xendit Test Mode**, retain the Invoice paid/expired callback:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-webhook
```

Use the sandbox checkout simulation and check callback delivery. Order ID, invoice ID, total and PHP currency are re-fetched/validated server-side. Existing attached invoices resume through the same integration. Closing checkout leaves payment pending until provider verification/expiry.

Refund approval is separate from money returned. An admin can enter a successful provider refund ID for channels exposing an invoice-linked refund through `/refunds`. The server verifies status/currency/amount/invoice before settlement. Unsupported, pending or unrelated references cannot be marked complete. If available for your sandbox channel, point `refund.succeeded` callbacks at the same function. Test the merchant's actual enabled sandbox methods before evaluation.

## 4. Android configuration and APK

Preserve the ignored existing `config/local.json`. Only public values belong here:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY",
  "ADVANCED_SHOPPING": true
}
```

`PAYMENT_API_URL` is no longer used. The advanced flag defaults false to avoid missing-table errors before setup. Enable it after steps 1-3, then build:

```powershell
flutter pub get
flutter build apk --release --dart-define-from-file=config/local.json --dart-define=ADVANCED_SHOPPING=true
```

Transfer/install `build/app/outputs/flutter-apk/app-release.apk` on the demonstration phone. Existing development signing is retained for classroom use. Android Internet permission and HTTPS cloud endpoints are configured. The phone needs internet, not your computer, a local server/IP or a tunnel.

## 5. Notifications and cloud jobs

All notifications persist in `tk_notifications` and are accessible in-app without Firebase. Orders, restock, rewards and support generate updates; promotions are opt-in.

Optional Android push: create a free Firebase Android app matching the existing application ID. Add its public `FCM_API_KEY`, `FCM_APP_ID`, `FCM_SENDER_ID`, `FCM_PROJECT_ID` to the Flutter build config; put only its service-account JSON in the Supabase secret above. Rebuild, allow notification permission and enable preferences. Firebase is only push transport; Auth and application data remain in Supabase. The app registers/refreshed tokens and deactivates account registrations on logout. Push taps check ownership and route to related screens; they never alter payment state.

`store-jobs` uses FCM HTTP v1/OAuth, checks current device owner/preferences, and leases queued deliveries with bounded retries. Messages contain generic text. A lost delivery response can cause a retry; taps are deduplicated. Without Firebase, in-app notifications remain fully functional and the worker performs only media cleanup.

Optionally schedule it in the same Supabase project using Cron (`pg_cron`), `pg_net` and Vault. No paid external scheduler is required. Enable the extensions and create Vault secrets `trendkicks_project_url` (cloud project URL) and `trendkicks_job_secret` (same as `STORE_JOB_SECRET`). Run once:

```sql
select cron.schedule('trendkicks-store-jobs', '* * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets
            where name = 'trendkicks_project_url') || '/functions/v1/store-jobs',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-store-job-secret', (select decrypted_secret from vault.decrypted_secrets
                            where name = 'trendkicks_job_secret')),
    body := '{}'::jsonb, timeout_milliseconds := 120000
  );
$$);
```

Review run history/function logs. Removed photos are purged in batches and failed pending uploads older than two hours are reclaimed. The function defined by `202610210003_reservation_cleanup.sql` also needs a schedule. If it is not already scheduled, run once:

```sql
select cron.schedule('trendkicks-reservation-cleanup', '*/5 * * * *',
  'select public.tk_expire_abandoned()');
```

Do not duplicate an existing reservation-cleanup schedule. It releases abandoned reservations without attached invoices; attached invoices require verified Xendit expiry. Free-tier quotas apply; check provider dashboards if the project pauses or reaches a quota.

## Feature demonstration paths

| Feature | Functional path |
|---|---|
| Vouchers | Admin Overview > Vouchers; checkout server apply/remove. Fixed/percentage, minimum, cap, dates, global/customer limits, first purchase and product/category scopes. |
| Fit finder | Product Details; deterministic Nike/adidas measured-foot guides for men's US 6-12, preferences and available size/color. Unsupported charts fall back honestly to the size guide. |
| Restock | Subscribe to exact sold-out size/color; admin changes stock from zero to positive; account receives persistent alert and can cancel subscriptions. |
| Addresses | Account address CRUD/default; checkout loads/selects address and retains delivery snapshot. |
| Comparison | Product Details; up to three shoes with prices, sizes/colors/stock/ratings/fit; guest accessible. |
| Rewards | Account balance/pending/history; admin rules; checkout whole-unit redemption. Earn only for paid-and-delivered orders. |
| Notifications | In-app updates and category preferences; promotions opt-in; optional free Android FCM. |
| Photo reviews | Delivered purchase > Write / edit review: rate, write and optionally attach up to three photos in one form, then Save review. Edit existing photos in that same form; public reports and admin moderation remain available. Private Storage and actual decode/re-encode; Android downsizes, server limits 5 MB, 6 MP and 100-6000 px. |
| Support | Account tickets with optional owned order, persisted conversation/reopening; admin search/filter/reply/status. |
| Analytics | Admin Overview > Sales reports; private aggregates, Manila dates, collection/refund/net and daily/monthly/product/status/method summaries, PDF export. |
| Order PDFs | Confirmation is available for unpaid orders and explicitly is not payment proof. Separate immutable numbered receipt requires verified payment or attested COD collection. |

Money uses integer centavos. Vouchers discount eligible merchandise first, then points; shipping stays payable. Online store floor is PHP 1, but channels may enforce higher minimums. Checkout locks protect inventory, voucher limits and points; stable retry keys return the same order. Unpaid cancellation/expiry releases stock/reservations once. Verified successful refunds are deduplicated/capped, reverse earned points proportionally (debt if spent) and release redeemed points once on full refund. Refunded voucher usage stays consumed; approval alone has no financial effect.

Reports use Asia/Manila boundaries and actual collections, excluding unpaid COD/invoices. Net means collections less verified refunds, not accounting profit. Historical paid rows missing timestamps use a flagged fallback; new receipts require trusted confirmation. Historical prices, discounts and delivery are immutable snapshots. `output/pdf` contains visual test samples only.

## Verification and remaining external steps

```powershell
flutter analyze --no-pub
flutter test --no-pub --dart-define=ADVANCED_SHOPPING=true
npm --prefix tools run test:postgres
npx --yes deno test --allow-env --allow-read --allow-net supabase/functions/_shared/
node tools/build_dashboard_functions.mjs
```

See [validation](VALIDATION.md) for executed results. Local tests use disposable databases/mocked provider HTTP; they do not change the cloud project. Hosted migrations, function redeployment, hosted Auth settings, physical-phone installation and live sandbox/FCM device checks still need to be completed in your project.

For evaluation, use a second phone to demonstrate signup, discounted sandbox checkout/callback/receipt, COD delivery/rewards, fit/comparison, address selection, exact-size restock, photo review, support reply, order-status updates, notifications and a filtered PDF report. Use test data throughout.

Primary references: [Supabase Edge image processing](https://supabase.com/docs/guides/functions/examples/image-manipulation), [cloud scheduling](https://supabase.com/docs/guides/functions/schedule-functions), [Xendit test keys](https://docs.xendit.co/docs/api-keys), [refund API](https://developers.xendit.co/api-reference/payments-api/), [FCM authorization](https://firebase.google.com/docs/cloud-messaging/auth-server).
