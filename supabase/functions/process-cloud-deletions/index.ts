import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type DeletionRequest = {
  teacher_id: string;
  scheduled_for: string;
};

Deno.serve(async (req) => {
  const cronSecret = Deno.env.get("CRON_SECRET");
  if (!cronSecret) {
    return jsonResponse({ error: "CRON_SECRET is not configured." }, 500);
  }

  if (req.headers.get("x-cron-secret") !== cronSecret) {
    return jsonResponse({ error: "Unauthorized." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse(
      { error: "Supabase environment is not configured." },
      500,
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });
  const now = new Date().toISOString();

  const { data: requests, error: fetchError } = await supabase
    .from("cloud_data_deletion_requests")
    .select("teacher_id, scheduled_for")
    .lte("scheduled_for", now)
    .order("scheduled_for")
    .limit(50);

  if (fetchError) {
    return jsonResponse({ error: fetchError.message }, 500);
  }

  const results = [];
  for (const request of (requests ?? []) as DeletionRequest[]) {
    const teacherId = request.teacher_id;
    const result = await deleteTeacherData(supabase, teacherId);
    results.push({ teacher_id: teacherId, ...result });
  }

  return jsonResponse({ processed: results.length, results });
});

async function deleteTeacherData(
  supabase: ReturnType<typeof createClient>,
  teacherId: string,
) {
  const tables = ["weekly_schedule", "lesson_records", "teacher_classes"];
  for (const table of tables) {
    const { error } = await supabase
      .from(table)
      .delete()
      .eq("teacher_id", teacherId);
    if (error) return { ok: false, error: `${table}: ${error.message}` };
  }

  const { error } = await supabase
    .from("cloud_data_deletion_requests")
    .delete()
    .eq("teacher_id", teacherId);
  if (error) {
    return {
      ok: false,
      error: `cloud_data_deletion_requests: ${error.message}`,
    };
  }

  return { ok: true };
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
