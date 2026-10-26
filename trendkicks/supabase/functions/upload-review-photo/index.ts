import {
  adminClient,
  cors,
  HttpError,
  json,
  userClient,
} from "../_shared/runtime.ts";
import { sanitizeReviewImage } from "../_shared/review_image.ts";

export async function uploadReviewPhoto(request: Request): Promise<Response> {
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }
  try {
    const { client, user } = await userClient(request);
    if (Number(request.headers.get("content-length") ?? 0) > 7100000) {
      throw new HttpError(413, "Choose a photo under 5 MB.");
    }
    // Bound the stream even when content-length is absent or forged.
    const reader = request.body?.getReader();
    if (!reader) throw new HttpError(400, "Photo is required.");
    const chunks: Uint8Array[] = [];
    let length = 0;
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > 7100000) {
        await reader.cancel();
        throw new HttpError(413, "Choose a smaller photo.");
      }
      chunks.push(value);
    }
    const raw = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) {
      raw.set(chunk, offset);
      offset += chunk.length;
    }
    let body;
    try {
      body = JSON.parse(new TextDecoder().decode(raw));
    } catch {
      throw new HttpError(400, "Invalid photo request.");
    }
    if (
      typeof body.review_id !== "string" ||
      !/^[0-9a-f-]{36}$/i.test(body.review_id) ||
      typeof body.bytes_base64 !== "string"
    ) throw new HttpError(400, "Invalid photo request.");
    // user_id is deliberately private: the customer role can read only the
    // public review columns. Check ownership on the server, using the identity
    // verified above, without exposing or granting access to that column.
    const admin = adminClient();
    const { data: review, error: reviewError } = await admin.from("tk_reviews")
      .select("id").eq("id", body.review_id).eq("user_id", user.id)
      .maybeSingle();
    if (reviewError) {
      throw new HttpError(503, "Could not verify your review. Please retry.");
    }
    if (!review) {
      throw new HttpError(403, "Only your own review can have photos.");
    }
    const { count, error: countError } = await client.from("tk_review_images")
      .select("id", {
        count: "exact",
        head: true,
      })
      .eq("review_id", body.review_id).in("status", ["PENDING", "VISIBLE"]);
    if (countError) {
      throw new HttpError(
        503,
        "Could not check your review photos. Please retry.",
      );
    }
    if ((count ?? 0) >= 3) {
      throw new HttpError(400, "Use up to three photos per review.");
    }
    let photo;
    try {
      photo = await sanitizeReviewImage(
        Uint8Array.from(atob(body.bytes_base64), (c) => c.charCodeAt(0)),
      );
    } catch {
      throw new HttpError(
        400,
        "Use a valid JPG or PNG photo under 5 MB and 6 MP. Update the app to upload WebP photos.",
      );
    }
    const { data: reserved, error } = await admin.rpc(
      "tk_reserve_review_image",
      {
        p_review: body.review_id,
        p_user: user.id,
        p_mime: photo.mime,
        p_bytes: photo.bytes.length,
        p_width: photo.width,
        p_height: photo.height,
      },
    );
    if (error || !reserved) {
      throw new HttpError(
        400,
        "Only delivered purchase reviews can have up to three photos.",
      );
    }
    const { error: uploadError } = await admin.storage.from("review-images")
      .upload(reserved.path, photo.bytes, {
        contentType: photo.mime,
        upsert: false,
      });
    if (uploadError) {
      await admin.from("tk_review_images").update({ status: "REMOVED" }).eq(
        "id",
        reserved.id,
      );
      throw new HttpError(503, "Photo upload failed. Please retry.");
    }
    const { data: visible, error: visibleError } = await admin.from(
      "tk_review_images",
    )
      .update({ status: "VISIBLE" }).eq("id", reserved.id).eq(
        "status",
        "PENDING",
      ).select("id").maybeSingle();
    if (visibleError || !visible) {
      await admin.from("tk_review_images").update({ status: "REMOVED" }).eq(
        "id",
        reserved.id,
      );
      await admin.storage.from("review-images").remove([reserved.path]);
      throw new HttpError(
        503,
        "Photo could not be published. Please refresh and retry.",
      );
    }
    return json({ id: reserved.id });
  } catch (error) {
    if (error instanceof HttpError) {
      return json({ error: error.message }, error.status);
    }
    console.error(
      "Photo upload failed",
      error instanceof Error ? error.name : "UnknownError",
    );
    return json({ error: "Photo upload is unavailable. Please retry." }, 503);
  }
}
if (Deno.env.get("TK_TESTING") !== "1") Deno.serve(uploadReviewPhoto);
