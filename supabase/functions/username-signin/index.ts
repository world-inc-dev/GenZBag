import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://world-inc-dev.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const headers = { ...cors, "Content-Type": "application/json" };
  if (req.method !== "POST") return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405, headers });

  try {
    const { username, password } = await req.json();
    const normalized = String(username ?? "").trim().toLowerCase();
    if (!/^[a-z0-9]{4,20}$/.test(normalized) || typeof password !== "string" || !password) {
      return new Response(JSON.stringify({ error: "Invalid username or password." }), { status: 400, headers });
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: profile, error: profileError } = await admin
      .from("profiles").select("id").eq("username", normalized).maybeSingle();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: "Invalid username or password." }), { status: 401, headers });
    }

    const { data: userData, error: userError } = await admin.auth.admin.getUserById(profile.id);
    const email = userData?.user?.email;
    if (userError || !email) {
      return new Response(JSON.stringify({ error: "Invalid username or password." }), { status: 401, headers });
    }

    const publicAuth = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: authData, error: authError } = await publicAuth.auth.signInWithPassword({ email, password });
    if (authError || !authData.session) {
      return new Response(JSON.stringify({ error: "Invalid username or password." }), { status: 401, headers });
    }

    return new Response(JSON.stringify({ session: authData.session }), { status: 200, headers });
  } catch (_error) {
    return new Response(JSON.stringify({ error: "Unable to sign in right now. Please try again." }), { status: 400, headers });
  }
});