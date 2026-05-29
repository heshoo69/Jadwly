import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type FcmTokenRow = {
  token: string;
  teacher_id: string;
};

type NotificationRequest = {
  title?: unknown;
  body?: unknown;
  teacher_id?: unknown;
  data?: unknown;
};

type SendResult = {
  token: string;
  ok: boolean;
  status: number;
  error?: string;
  invalidToken?: boolean;
};

const firebaseScope = "https://www.googleapis.com/auth/firebase.messaging";
const sendBatchSize = 20;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const pushSecret = Deno.env.get("PUSH_NOTIFICATION_SECRET");
  if (!pushSecret) {
    return jsonResponse(
      { error: "PUSH_NOTIFICATION_SECRET is not configured." },
      500,
    );
  }

  if (req.headers.get("x-push-secret") !== pushSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const config = firebaseConfig();
  if ("error" in config) {
    return jsonResponse({ error: config.error }, 500);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: "Supabase environment is not configured." },
      500,
    );
  }

  let payload: NotificationRequest;
  try {
    payload = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Request body must be valid JSON." }, 400);
  }

  const validation = validatePayload(payload);
  if ("error" in validation) {
    return jsonResponse({ error: validation.error }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  let query = supabase
    .from("fcm_tokens")
    .select("token, teacher_id")
    .order("last_seen_at", { ascending: false });

  if (validation.teacherId) {
    query = query.eq("teacher_id", validation.teacherId);
  }

  const { data: tokens, error: tokenError } = await query;
  if (tokenError) {
    return jsonResponse({ error: tokenError.message }, 500);
  }

  const rows = ((tokens ?? []) as FcmTokenRow[]).filter((row) =>
    row.token.trim() !== ""
  );
  if (rows.length === 0) {
    return jsonResponse({
      attempted: 0,
      sent: 0,
      failed: 0,
      deletedInvalidTokens: 0,
      target: validation.teacherId ? "teacher" : "all",
    });
  }

  const accessToken = await fetchFirebaseAccessToken(config);
  if ("error" in accessToken) {
    return jsonResponse({ error: accessToken.error }, 500);
  }

  const results: SendResult[] = [];
  for (const batch of chunk(rows, sendBatchSize)) {
    const batchResults = await Promise.all(
      batch.map((row) =>
        sendFirebaseMessage({
          accessToken: accessToken.token,
          projectId: config.projectId,
          token: row.token,
          title: validation.title,
          body: validation.body,
          data: validation.data,
        })
      ),
    );
    results.push(...batchResults);
  }

  const invalidTokens = results
    .filter((result) => result.invalidToken)
    .map((result) => result.token);
  if (invalidTokens.length > 0) {
    await supabase.from("fcm_tokens").delete().in("token", invalidTokens);
  }

  const sent = results.filter((result) => result.ok).length;
  return jsonResponse({
    attempted: results.length,
    sent,
    failed: results.length - sent,
    deletedInvalidTokens: invalidTokens.length,
    target: validation.teacherId ? "teacher" : "all",
    teacher_id: validation.teacherId,
    errors: results
      .filter((result) => !result.ok)
      .slice(0, 10)
      .map((result) => ({
        status: result.status,
        error: result.error,
        invalidToken: result.invalidToken === true,
      })),
  });
});

function validatePayload(payload: NotificationRequest):
  | {
    title: string;
    body: string;
    teacherId?: string;
    data?: Record<string, string>;
  }
  | { error: string } {
  const title = typeof payload.title === "string" ? payload.title.trim() : "";
  const body = typeof payload.body === "string" ? payload.body.trim() : "";
  if (!title || !body) {
    return { error: "Both title and body are required." };
  }

  const teacherId = typeof payload.teacher_id === "string"
    ? payload.teacher_id.trim()
    : "";
  if (payload.teacher_id != null && !teacherId) {
    return { error: "teacher_id must be a non-empty string when provided." };
  }

  const data = normalizeData(payload.data);
  if ("error" in data) return data;

  return {
    title,
    body,
    teacherId: teacherId || undefined,
    data: data.value,
  };
}

function normalizeData(
  data: unknown,
): { value?: Record<string, string> } | { error: string } {
  if (data == null) return {};
  if (typeof data !== "object" || Array.isArray(data)) {
    return { error: "data must be an object when provided." };
  }

  const normalized: Record<string, string> = {};
  for (const [key, value] of Object.entries(data)) {
    if (typeof value !== "string") {
      return { error: "data values must be strings." };
    }
    normalized[key] = value;
  }
  return { value: normalized };
}

function firebaseConfig():
  | {
    projectId: string;
    clientEmail: string;
    privateKey: string;
  }
  | { error: string } {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(
    /\\n/g,
    "\n",
  );

  if (!projectId || !clientEmail || !privateKey) {
    return { error: "Firebase service account environment is not configured." };
  }

  return { projectId, clientEmail, privateKey };
}

async function fetchFirebaseAccessToken(config: {
  clientEmail: string;
  privateKey: string;
}): Promise<{ token: string } | { error: string }> {
  const now = Math.floor(Date.now() / 1000);
  const jwt = await createServiceAccountJwt({
    clientEmail: config.clientEmail,
    privateKey: config.privateKey,
    issuedAt: now,
    expiresAt: now + 3600,
  });

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const body = await response.json().catch(() => ({})) as Record<
    string,
    unknown
  >;
  const accessToken = body["access_token"];
  if (!response.ok || typeof accessToken !== "string") {
    return {
      error: `Could not fetch Firebase access token: ${
        JSON.stringify(body)
      }`,
    };
  }

  return { token: accessToken };
}

async function createServiceAccountJwt(args: {
  clientEmail: string;
  privateKey: string;
  issuedAt: number;
  expiresAt: number;
}) {
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: args.clientEmail,
    scope: firebaseScope,
    aud: "https://oauth2.googleapis.com/token",
    iat: args.issuedAt,
    exp: args.expiresAt,
  };

  const unsignedJwt = `${base64UrlEncodeJson(header)}.${
    base64UrlEncodeJson(claims)
  }`;
  const key = await importPrivateKey(args.privateKey);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedJwt),
  );

  return `${unsignedJwt}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function importPrivateKey(privateKey: string) {
  const pem = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binary,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

async function sendFirebaseMessage(args: {
  accessToken: string;
  projectId: string;
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<SendResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${args.projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${args.accessToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: args.token,
          notification: {
            title: args.title,
            body: args.body,
          },
          data: args.data,
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
          android: {
            notification: {
              sound: "default",
              channel_id: "firebase_messages",
            },
          },
        },
      }),
    },
  );

  const body = await response.json().catch(() => ({}));
  if (response.ok) {
    return { token: args.token, ok: true, status: response.status };
  }

  const fcmErrorCode = findFirebaseFcmErrorCode(body);
  const errorCode = fcmErrorCode ?? findFirebaseStatus(body);
  return {
    token: args.token,
    ok: false,
    status: response.status,
    error: errorCode ?? JSON.stringify(body),
    invalidToken: isInvalidTokenError(fcmErrorCode),
  };
}

function findFirebaseStatus(body: unknown): string | undefined {
  if (typeof body !== "object" || body == null) return undefined;
  const error = (body as Record<string, unknown>)["error"];
  if (typeof error !== "object" || error == null) return undefined;

  const status = (error as Record<string, unknown>)["status"];
  return typeof status === "string" ? status : undefined;
}

function findFirebaseFcmErrorCode(body: unknown): string | undefined {
  if (typeof body !== "object" || body == null) return undefined;
  const error = (body as Record<string, unknown>)["error"];
  if (typeof error !== "object" || error == null) return undefined;

  const details = (error as Record<string, unknown>)["details"];
  if (!Array.isArray(details)) return undefined;

  for (const detail of details) {
    if (typeof detail !== "object" || detail == null) {
      continue;
    }
    const errorCode = (detail as Record<string, unknown>)["errorCode"];
    if (typeof errorCode === "string") {
      return errorCode;
    }
  }

  return undefined;
}

function isInvalidTokenError(errorCode: string | undefined) {
  return errorCode === "UNREGISTERED" || errorCode === "INVALID_ARGUMENT";
}

function base64UrlEncodeJson(value: unknown) {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

function base64UrlEncode(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function chunk<T>(items: T[], size: number) {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
