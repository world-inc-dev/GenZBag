import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

async function dispatchReferralEmails(admin: ReturnType<typeof createClient>, activationId: string, adminTestRecipient: string) {
  const { data: queued, error } = await admin
    .from("email_outbox")
    .select("id,user_id,recipient_email,subject,html_body,text_body,attempts")
    .eq("activation_submission_id", activationId)
    .eq("status", "pending")
    .order("created_at", { ascending: true });

  if (error) {
    console.error("Could not load referral email outbox:", error.message);
    return { sent: 0, queued: 0, setupRequired: false, error: "Email queue could not be loaded." };
  }
  if (!queued?.length) return { sent: 0, queued: 0, setupRequired: false };

  const apiKey = Deno.env.get("RESEND_API_KEY");
  const productionFrom = Deno.env.get("GENZBAG_FROM_EMAIL");
  if (!apiKey) return { sent: 0, queued: queued.length, setupRequired: true };

  let sent = 0;
  for (const item of queued) {
    try {
      const isVerifiedAdminRecipient = String(item.recipient_email || "").trim().toLowerCase() === String(adminTestRecipient || "").trim().toLowerCase();
      const sender = isVerifiedAdminRecipient ? "GenZBag Test <onboarding@resend.dev>" : productionFrom;
      if (!sender) throw new Error("Production email sender is not configured.");
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": "Bearer " + apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: sender,
          to: [item.recipient_email],
          subject: item.subject,
          html: item.html_body,
          text: item.text_body,
        }),
      });
      const responseBody = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(responseBody?.message || responseBody?.name || ("Resend returned " + response.status));

      const { error: updateError } = await admin.from("email_outbox").update({
        status: "sent",
        attempts: Number(item.attempts || 0) + 1,
        sent_at: new Date().toISOString(),
        last_error: null,
      }).eq("id", item.id);
      if (updateError) throw updateError;
      sent++;
    } catch (err) {
      const message = err instanceof Error ? err.message : "Email delivery failed.";
      await admin.from("email_outbox").update({
        attempts: Number(item.attempts || 0) + 1,
        last_error: message.slice(0, 1000),
      }).eq("id", item.id);
      console.error("Referral email delivery failed:", message);
    }
  }
  return { sent, queued: queued.length - sent, setupRequired: false };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "");
    if (!token) return json({ error: "Sign in as an administrator." }, 401);

    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const callerClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: callerData, error: callerError } = await callerClient.auth.getUser(token);
    const caller = callerData?.user;
    if (callerError || !caller || caller.app_metadata?.role !== "admin") {
      return json({ error: "Administrator authorization required." }, 403);
    }

    const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const body = await req.json();
    const action = String(body?.action || "");
    const now = new Date().toISOString();

    if (action === "test_email") {
      const apiKey = Deno.env.get("RESEND_API_KEY");
      // Resend's shared testing sender is restricted to the email address on the Resend account.
      // Keep the production/referral sender secret unchanged; this override is test_email only.
      const from = "GenZBag Test <onboarding@resend.dev>";
      const recipient = String(caller.email || "").trim();
      if (!apiKey || !from) return json({ error: "Email setup is incomplete. Check RESEND_API_KEY and GENZBAG_FROM_EMAIL in Supabase Edge Function secrets." }, 503);
      if (!recipient) return json({ error: "Your administrator account has no email address to receive the test." }, 400);
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": "Bearer " + apiKey, "Content-Type": "application/json" },
        body: JSON.stringify({
          from,
          to: [recipient],
          subject: "GenZBag email delivery test",
          html: "<div style='font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;color:#172033'><h2 style='color:#0d9488'>GenZBag email is connected</h2><p>This is a test message sent from the GenZBag administrator dashboard.</p><p>Your email delivery configuration is responding successfully.</p><hr><small>© 2026 GenZBag</small></div>",
          text: "GenZBag email is connected. This test message confirms that the administrator dashboard can send email. © 2026 GenZBag"
        })
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) {
        console.error("GenZBag test email failed:", result?.message || response.status);
        return json({ error: result?.message || ("Resend returned " + response.status) }, 502);
      }
      await admin.from("admin_audit_logs").insert({
        admin_id: caller.id, action: "admin_test_email_sent", target_type: "admin", target_id: caller.id,
        details: { recipient, resend_email_id: result?.id || null }
      });
      return json({ ok: true, message: "Test email accepted by Resend.", recipient, email_id: result?.id || null });
    }

    if (action === "get_financial_summary") {
      const { data, error } = await admin.rpc("admin_financial_summary");
      if (error) return json({ error: "Financial summary could not be loaded: " + error.message }, 400);
      return json({ ok: true, summary: data });
    }

    if (action === "update_member") {
      const userId = String(body.user_id || "");
      const username = String(body.username || "").trim().toLowerCase();
      const email = String(body.email || "").trim().toLowerCase();
      const phone = String(body.phone || "").trim();
      if (!userId || !/^[a-z0-9_]{3,30}$/.test(username) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || phone.length > 32) {
        return json({ error: "Enter a valid username, email address and phone number." }, 400);
      }
      const { data: existing, error: lookupError } = await admin.auth.admin.getUserById(userId);
      if (lookupError || !existing?.user) return json({ error: "Member account not found." }, 404);
      const before = { username: null as string | null, email: existing.user.email || null, phone: null as string | null };
      const { data: oldProfile } = await admin.from("profiles").select("username,phone,contact_email").eq("id", userId).maybeSingle();
      before.username = oldProfile?.username || null;
      before.phone = oldProfile?.phone || null;
      if (existing.user.email !== email) {
        const { error } = await admin.auth.admin.updateUserById(userId, { email, email_confirm: true });
        if (error) return json({ error: "Email update failed: " + error.message }, 400);
      }
      const { error: profileError } = await admin.from("profiles").update({
        username, contact_email: email, phone: phone || null, updated_at: now,
      }).eq("id", userId);
      if (profileError) return json({ error: "Profile update failed: " + profileError.message }, 400);
      await admin.from("admin_audit_logs").insert({
        admin_id: caller.id, action: "member_profile_updated", target_type: "user", target_id: userId,
        details: { before, after: { username, email, phone } },
      });
      return json({ ok: true, message: "Member details updated." });
    }

    if (action === "list_member_access") {
      const userIds = Array.isArray(body.user_ids) ? [...new Set(body.user_ids.map((v: unknown) => String(v || "")))].filter((v: string) => /^[0-9a-f-]{36}$/i.test(v)).slice(0, 500) : [];
      if (!userIds.length) return json({ ok: true, members: [] });
      const results = await Promise.all(userIds.map(async (userId: string) => {
        const { data, error } = await admin.auth.admin.getUserById(userId);
        if (error || !data?.user) return { user_id: userId, found: false, suspended: null, banned_until: null };
        const bannedUntil = data.user.banned_until || null;
        const suspended = !!bannedUntil && new Date(bannedUntil).getTime() > Date.now();
        return { user_id: userId, found: true, suspended, banned_until: bannedUntil };
      }));
      return json({ ok: true, members: results });
    }

    if (action === "set_member_access") {
      const userId = String(body.user_id || "");
      const suspended = body.suspended === true;
      const note = String(body.note || "").trim().slice(0, 500);
      if (!/^[0-9a-f-]{36}$/i.test(userId)) return json({ error: "A valid member account is required." }, 400);
      if (note.length < 5) return json({ error: "Provide an audit reason of at least 5 characters." }, 400);
      if (userId === caller.id) return json({ error: "You cannot suspend your own administrator account." }, 400);
      const { data: target, error: targetError } = await admin.auth.admin.getUserById(userId);
      if (targetError || !target?.user) return json({ error: "Member account not found." }, 404);
      if (target.user.app_metadata?.role === "admin") return json({ error: "Administrator accounts cannot be suspended from member management." }, 403);
      const { data: changed, error: changeError } = await admin.auth.admin.updateUserById(userId, {
        ban_duration: suspended ? "876000h" : "none",
      });
      if (changeError || !changed?.user) return json({ error: "Account access could not be updated: " + (changeError?.message || "Unknown error"), }, 400);
      const bannedUntil = changed.user.banned_until || null;
      const isSuspended = !!bannedUntil && new Date(bannedUntil).getTime() > Date.now();
      await admin.from("admin_audit_logs").insert({
        admin_id: caller.id,
        action: isSuspended ? "member_access_suspended" : "member_access_restored",
        target_type: "user",
        target_id: userId,
        details: { note, banned_until: bannedUntil },
      });
      return json({ ok: true, suspended: isSuspended, banned_until: bannedUntil, message: isSuspended ? "Member sign-in access suspended." : "Member sign-in access restored." });
    }

    if (action === "review_withdrawal") {
      const id = String(body.id || "");
      const status = String(body.status || "");
      const note = String(body.note || "").trim().slice(0, 500);
      const providerReference = String(body.provider_reference || "").trim().slice(0, 120);
      if (!id || !["under_review", "approved", "rejected", "paid"].includes(status)) {
        return json({ error: "Invalid withdrawal decision." }, 400);
      }
      if (status === "paid" && providerReference.length < 5) {
        return json({ error: "Enter the actual mobile money transaction reference before recording payment." }, 400);
      }
      const { data, error } = await admin.rpc("admin_review_withdrawal", {
        p_request_id: id, p_status: status, p_note: note, p_provider_reference: providerReference,
      });
      if (error || !data?.success) return json({ error: error?.message || "Withdrawal request could not be updated." }, 400);
      await admin.from("admin_audit_logs").insert({
        admin_id: caller.id, action: "withdrawal_" + status, target_type: "withdrawal_request", target_id: id,
        details: { request_id: id, note, provider_reference: status === "paid" ? providerReference : null },
      });
      const message = status === "paid" ? "Payout recorded with transaction reference."
        : status === "rejected" ? "Request rejected and reserved funds returned to the member."
        : "Withdrawal review decision saved.";
      return json({ ok: true, message });
    }

    if (action === "review_activation") {
      const id = String(body.id || "");
      const status = String(body.status || "");
      const note = String(body.note || "").trim().slice(0, 500);
      if (!id || !["verified", "rejected"].includes(status)) return json({ error: "Invalid activation decision." }, 400);
      const { data: current, error: currentError } = await admin.from("activation_payment_submissions")
        .select("id,user_id,status").eq("id", id).maybeSingle();
      if (currentError || !current) return json({ error: currentError?.message || "Activation submission not found." }, 404);
      if (current.status !== "pending") {
        return json({ error: "This activation has already been " + (current.status === "verified" ? "approved" : "rejected") + ". Its decision cannot be changed." }, 409);
      }
      const { data, error } = await admin.from("activation_payment_submissions").update({
        status, admin_note: note || null, reviewed_by: caller.id, reviewed_at: now,
      }).eq("id", id).eq("status", "pending").select("id,user_id,status").maybeSingle();
      if (error || !data) return json({ error: error?.message || "Activation could not be reviewed. Refresh and try again." }, 400);

      let emailDelivery = { sent: 0, queued: 0, setupRequired: false as boolean, error: undefined as string | undefined };
      if (status === "verified") emailDelivery = await dispatchReferralEmails(admin, id, String(caller.email || "").trim());

      await admin.from("admin_audit_logs").insert({
        admin_id: caller.id, action: "activation_" + status, target_type: "activation_submission", target_id: id,
        details: { user_id: data.user_id, note, referral_emails_sent: emailDelivery.sent, referral_emails_queued: emailDelivery.queued },
      });
      return json({ ok: true, message: status === "verified" ? "Activation approved. Referral commissions and platform retention have been recorded." : "Activation rejected.", referral_emails: emailDelivery });
    }

    return json({ error: "Unsupported administrator action." }, 400);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "Unexpected server error." }, 500);
  }
});