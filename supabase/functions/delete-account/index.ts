// delete-account — removes the calling user's account.
//
// The app calls this with the user's access token (the Supabase SDK adds the Authorization
// header automatically). The function verifies that token, then deletes that user — and only
// that user — through the Admin API with the service_role key. The key is read from the
// function's environment (Supabase injects SUPABASE_SERVICE_ROLE_KEY into every function); it is
// never shipped in the app.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json(405, { error: "Use POST" });
  }

  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "");
  if (!token) {
    return json(401, { error: "Missing bearer token" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json(500, { error: "Function is missing its Supabase environment" });
  }

  // Verify the caller: a client scoped to the caller's token asks Auth who they are.
  const asCaller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: userError } = await asCaller.auth.getUser(token);
  if (userError || !user) {
    return json(401, { error: "Invalid or expired token" });
  }

  // Delete exactly that user with the service role. `profiles` is removed by the cascade.
  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("delete-account failed", { userId: user.id, message: deleteError.message });
    return json(500, { error: "Could not delete the account" });
  }

  return json(200, { deleted: true });
});
