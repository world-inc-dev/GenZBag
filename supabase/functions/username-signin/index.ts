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
  const declaredLength = Number(req.headers.get("content-length") || 0);
  if (declaredLength > 4096) return new Response(JSON.stringify({ error: "Request is too large." }), { status: 413, headers });

  try {
    const { username, password } = await req.json();
    const normalized = String(username ?? "").trim().toLowerCase();
    if (!/^[a-z0-9]{4,20}$/.test(normalized) || typeof password !== "string" || password.length < 1 || password.length > 256) {
      return new Response(JSON.stringify({ error: "Invalid username or password." }), { status: 400, headers });
    }

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const ip = req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip") ||
      (req.headers.get("x-forwarded-for") || "unknown").split(",")[0].trim() || "unknown";
    const hashKey = async (value: string) => {
      const bytes = new TextEncoder().encode(value + ":" + serviceKey);
      const digest = await crypto.subtle.digest("SHA-256", bytes);
      return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
    };
    const limiter = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const [ipAllowed, accountAllowed] = await Promise.all([
      limiter.rpc("consume_edge_rate_limit", { p_key_hash: await hashKey("username-signin-ip:" + ip), p_limit: 60, p_window_seconds: 900 }),
      limiter.rpc("consume_edge_rate_limit", { p_key_hash: await hashKey("username-signin-account:" + ip + ":" + normalized), p_limit: 8, p_window_seconds: 900 }),
    ]);
    if (ipAllowed.error || accountAllowed.error) {
      console.error("Username sign-in rate limit failed:", ipAllowed.error?.message || accountAllowed.error?.message);
      return new Response(JSON.stringify({ error: "Sign-in is temporarily unavailable. Please try again shortly." }), { status: 503, headers });
    }
    if (ipAllowed.data !== true || accountAllowed.data !== true) {
      return new Response(JSON.stringify({ error: "Too many sign-in attempts. Please wait 15 minutes before trying again." }), { status: 429, headers });
    }
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