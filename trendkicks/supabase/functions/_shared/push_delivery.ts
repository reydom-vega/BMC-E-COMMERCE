type ServiceAccount = {
  project_id: string;
  client_email: string;
  private_key: string;
};
const base64url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
export function createPushSender(account: ServiceAccount) {
  let accessToken: string | undefined;
  return async (token: string, data: Record<string, string>) => {
    if (!accessToken) {
      const encode = (obj: unknown) =>
        base64url(new TextEncoder().encode(JSON.stringify(obj)));
      const now = Math.floor(Date.now() / 1000);
      const unsigned = encode({ alg: "RS256", typ: "JWT" }) + "." + encode({
        iss: account.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3500,
      });
      const pem = account.private_key.replace(/-----[^-]+-----|\s/g, "");
      const key = await crypto.subtle.importKey(
        "pkcs8",
        Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
        { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
        false,
        ["sign"],
      );
      const signature = await crypto.subtle.sign(
        "RSASSA-PKCS1-v1_5",
        key,
        new TextEncoder().encode(unsigned),
      );
      const auth = await fetch("https://oauth2.googleapis.com/token", {
        method: "POST",
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion: unsigned + "." + base64url(new Uint8Array(signature)),
        }),
        signal: AbortSignal.timeout(15000),
      });
      if (!auth.ok) throw new Error("Push authorization failed");
      accessToken = (await auth.json()).access_token;
      if (!accessToken) throw new Error("Push authorization failed");
    }
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${
        encodeURIComponent(account.project_id)
      }/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            data,
            notification: {
              title: "Trend Kicks update",
              body: "Open Trend Kicks to view your latest update.",
            },
            android: {
              priority: "HIGH",
              notification: { tag: data.notification_id },
            },
          },
        }),
        signal: AbortSignal.timeout(15000),
      },
    );
    if (!response.ok) throw new Error("Push delivery failed");
  };
}
