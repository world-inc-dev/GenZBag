import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://world-inc-dev.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" } });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

    const body = await req.json();
    const username = String(body?.username || "").trim().toLowerCase();
    const email = String(body?.email || "").trim().toLowerCase();
    const phone = String(body?.phone || "").trim();
    const phoneDigits = phone.replace(/[^0-9]/g, "");
    // Availability is checked independently as each signup field is entered.
    // Empty sibling fields are expected; validate only values supplied by the browser.
    const hasUsername = username.length > 0;
    const hasEmail = email.length > 0;
    const hasPhone = phone.length > 0;
    if (!hasUsername && !hasEmail && !hasPhone) {
      return json({ error: "Enter a username, email or phone number to check." }, 400);
    }
    if ((hasUsername && !/^[a-z0-9]{4,20}$/.test(username)) ||
        (hasEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) ||
        (hasPhone && (phoneDigits.length < 9 || phoneDigits.length > 16))) {
      return json({ error: "Enter a valid value before checking availability." }, 400);
    }

    const forwarded = req.headers.get("x-forwarded-for") || "";
    const ip = req.headers.get("cf-connecting-ip") || req.headers.get("x-real-ip") || forwarded.split(",").pop()?.trim() || "unknown";
    const bytes = new TextEncoder().encode(ip + ":" + serviceKey);
    const digest = await crypto.subtle.digest("SHA-256", bytes);
    const ipHash = Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");

    const { data: allowed, error: limitError } = await admin.rpc("consume_signup_availability_rate_limit", { p_ip_hash: ipHash });
    if (limitError) {
      console.error("Signup availability rate limit failed:", limitError.message);
      return json({ error: "Availability checks are temporarily unavailable." }, 503);
    }
    if (allowed !== true) return json({ error: "Too many availability checks. Please wait 15 minutes and try again." }, 429);

    const { data, error } = await admin.rpc("check_signup_availability", {
      p_username: username,
      p_email: email,
      p_phone: phone,
    });
    if (error) {
      console.error("Signup availability lookup failed:", error.message);
      return json({ error: "Availability checks are temporarily unavailable." }, 503);
    }
    return json(data || {});
  } catch (error) {
    console.error("Signup availability error:", error);
    return json({ error: "Availability checks are temporarily unavailable." }, 500);
  }
});