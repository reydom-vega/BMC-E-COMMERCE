# Trend Kicks

An **Android Flutter sneaker e-commerce school project** built with Dart, the existing cloud Supabase and **Xendit sandbox payments in Philippine Pesos (PHP)**.

The original Trend Kicks logo, lime/black palette, typography, customer/admin navigation, wishlist, filters and Light/Dark/**Default** appearance are preserved. Continue to payment opens Xendit checkout directly; closing checkout or receiving a notification never marks an order paid.

## Project scope

The Android app connects over HTTPS to Supabase database, authentication, Storage and Edge Functions. It works on another internet-connected Android phone without your development computer running. No website, custom domain, hosting subscription, PHP server, ngrok or paid courier API is required. Existing optional Flutter platform folders remain for compatibility; Android is the demonstration target.

The user's October 24 scope update overrides hosting/PHP migration instructions in the supplied implementation prompt. Original reference documents remain in [docs/reference](docs/reference).

See the [October 25 bug-fix notes](docs/BUGFIXES_20261025.md) for automatic discounts, PDF viewing, Firebase configuration and the new additive migration. Courier tracking UI was removed; basic order statuses remain.

The latest review/photo fixes repair the review-dialog crash, refresh product reviews/ratings/photos, and remove the photo function's separate WASM dependency. Install the newest debug APK and redeploy the updated [upload-review-photo Dashboard copy](docs/deploy/upload-review-photo.ts); these follow-up fixes require no new SQL migration.

## Features

- Catalog, search, combined filters, size guides, private account/device guest wishlist, cart and live inventory.
- Supabase accounts, customer profiles, admin roles, COD and sandbox Xendit payments, stock reservations, cancellations/expiry, reviews and refund approval.
- Advanced features: **vouchers, fit finder, exact-variant restock, address book, three-shoe comparison, loyalty rewards, optional Android push with in-app fallback, photo reviews, support tickets, admin analytics/PDF reports, order confirmation/payment receipt PDFs**.
- Delivered purchases use one review form for the rating, written review and up to three optional photos. Existing photos can be managed when editing the same review.
- Server-calculated centavo totals, locked voucher/points redemption, verified payment callbacks, immutable financial records and owner/admin RLS.

[Android/Supabase setup](docs/ADVANCED_SETUP.md) covers the additive migrations, four Edge Functions and demonstration steps. See [source map](docs/ADVANCED_CHANGES.md) and [validation evidence](docs/VALIDATION.md).

## Run and build Android

Developed with Flutter 3.47.2 / Dart 3.13.2. Install Flutter and the Android SDK, then connect a phone or emulator.

1. Complete the cloud setup linked above; apply only migrations not already installed.
2. Copy `config/example.json` to ignored `config/local.json` **only if it does not already exist**. Set the cloud URL and public publishable/anon key. Enable `ADVANCED_SHOPPING` after applying the advanced migrations and updating functions.
3. Run:

```powershell
cd C:\FINALS-BMC\trendkicks
flutter pub get
flutter run --dart-define-from-file=config/local.json
flutter build apk --release --dart-define-from-file=.env
config/local.json --dart-define=ADVANCED_SHOPPING=true
```

APK: `build/app/outputs/flutter-apk/app-release.apk`. The existing development signing setup is retained for classroom installation. Transfer/install it on another Android phone and use internet access; no localhost backend belongs in the config.

Without Supabase configuration, the app shows a clearly labeled sample catalog and guest bag/wishlist. Live accounts/orders/payments require cloud setup. Use sample sneakers, test customers and sandbox transactions for evaluation.

On Windows, enable Developer Mode if Flutter reports a plugin symlink requirement during `flutter pub get`.

## Local checks

```powershell
flutter analyze --no-pub
flutter test --no-pub --dart-define=ADVANCED_SHOPPING=true
npm --prefix tools install
npm --prefix tools run test:postgres
npx --yes deno test --allow-env --allow-read --allow-net supabase/functions/_shared/
```

Only public Supabase configuration belongs in Flutter. Service-role keys, Xendit secrets, callback/job tokens and Firebase service accounts stay server-side. Existing ignored credentials were not overwritten; hosted migrations/settings/functions were not changed automatically.
