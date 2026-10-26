import { adminClient, env, HttpError, json } from "../_shared/runtime.ts";
import { tokensEqual } from "../_shared/payment_rules.ts";
import { createPushSender } from "../_shared/push_delivery.ts";

export async function storeJobs(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }
  try {
    if (
      !tokensEqual(
        request.headers.get("x-store-job-secret") ?? "",
        env("STORE_JOB_SECRET"),
      )
    ) {
      return json({ error: "Unauthorized." }, 401);
    }
    const admin = adminClient();
    let delivered = 0;
    // In-app notifications work without any Firebase setup.
    const account = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (account) {
      const send = createPushSender(JSON.parse(account));
      const { data: jobs, error } = await admin.rpc("tk_claim_push", {
        p_limit: 5,
      });
      if (error) throw new HttpError(503, "Could not claim notifications.");
      for (const job of jobs ?? []) {
        let status = "PENDING", failure: string | null = null;
        try {
          const [device, preferences] = await Promise.all([
            admin.from("tk_device_tokens").select("user_id,active").eq(
              "token",
              job.token,
            ).maybeSingle(),
            admin.from("tk_notification_preferences").select("*").eq(
              "user_id",
              job.user_id,
            ).maybeSingle(),
          ]);
          if (device.error || preferences.error) {
            throw new Error("Preference check unavailable");
          }
          if (
            !device.data?.active || device.data.user_id !== job.user_id ||
            !preferences.data?.push_enabled || !preferences.data[job.category]
          ) status = "SKIPPED";
          else {
            await send(job.token, {
              notification_id: job.notification_id,
              owner_id: job.user_id,
              category: job.category,
              target_id: job.target_id ?? "",
            });
            status = "DELIVERED";
            delivered++;
          }
        } catch {
          failure = "delivery_failed";
        }
        const { error } = await admin.rpc("tk_finish_push", {
          p_id: job.id,
          p_lease: job.lease_id,
          p_status: status,
          p_error: failure,
        });
        if (error) {
          throw new HttpError(503, "Could not record notification delivery.");
        }
      }
    }
    const cutoff = new Date(Date.now() - 7200000).toISOString();
    const { data: media, error } = await admin.from("tk_review_images").select(
      "id,path",
    )
      .is("purged_at", null).or(
        `status.eq.REMOVED,and(status.eq.PENDING,created_at.lt.${cutoff})`,
      ).limit(20);
    if (error) throw new HttpError(503, "Could not read media cleanup queue.");
    let purged = 0;
    for (const row of media ?? []) {
      const { error } = await admin.storage.from("review-images").remove([
        row.path,
      ]);
      if (error) continue;
      const { error: updated } = await admin.from("tk_review_images")
        .update({ status: "REMOVED", purged_at: new Date().toISOString() }).eq(
          "id",
          row.id,
        );
      if (!updated) purged++;
    }
    return json({ delivered, purged, push_configured: !!account });
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status);
    }
    console.error(
      "Store job failed",
      error instanceof Error ? error.name : "UnknownError",
    );
    return json(
      { error: "Store job could not finish. Retry next batch." },
      503,
    );
  }
}
if (Deno.env.get("TK_TESTING") !== "1") Deno.serve(storeJobs);
