# Paste into Supabase Dashboard

Follow [Android setup](../ADVANCED_SETUP.md) to apply missing migrations, then create/update **four** Edge Functions:

1. `create-invoice` (existing)
2. `xendit-webhook` (existing)
3. `upload-review-photo`
4. `store-jobs`

Replace each editor's `index.ts` with the complete matching `.ts` file here and deploy. These copies include shared helpers; **do not create an `_shared` function**. Disable gateway JWT verification as in `supabase/config.toml`. User functions verify Supabase tokens, the webhook verifies its Xendit callback token, and the worker verifies a private job secret.

Set server secrets from `supabase/functions/.env.example` using a Xendit **test** key. Never put payment/service-role/job/FCM secrets in Flutter. In-app notifications work without FCM. Schedule cleanup/push inside Supabase if desired; no separate host is needed.

Keep Xendit's Test Mode invoice callback:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-webhook
```

No PHP cutover, website, custom domain or ngrok is required. All money is PHP.

Canonical source remains `supabase/functions`. Regenerate/check after changes:

```powershell
node tools/build_dashboard_functions.mjs
npx --yes deno check docs/deploy/create-invoice.ts docs/deploy/xendit-webhook.ts docs/deploy/upload-review-photo.ts docs/deploy/store-jobs.ts
```

CLI deployments use canonical files directly. Photo validation uses pinned pure JavaScript JPEG/PNG decoders and re-encodes fresh pixels without metadata. There is no separate WASM asset to bundle. Android converts JPG, PNG and WebP selections into a bounded JPEG before upload. After replacing `upload-review-photo`, check a small uploaded photo on the hosted function before evaluation.
