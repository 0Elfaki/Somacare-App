// Supabase Edge Function: mints short-lived Agora RTC tokens.
//
// The Agora App Certificate is a server-side secret and must never be
// shipped inside the Flutter app. This function holds it as an Edge
// Function secret (set via the Supabase Dashboard, never committed here)
// and returns a token scoped to one channel for a limited time.
//
// Deploy via Supabase Dashboard -> Edge Functions -> Deploy a new function
// (paste this file's contents), then set secrets:
//   AGORA_APP_ID           = 72656e25ae404defb07daea155e9806f
//   AGORA_APP_CERTIFICATE  = <the certificate value - never commit it>

import { RtcRole, RtcTokenBuilder } from "npm:agora-access-token@2.0.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const APP_ID = Deno.env.get("AGORA_APP_ID") ?? "";
const APP_CERTIFICATE = Deno.env.get("AGORA_APP_CERTIFICATE") ?? "";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!APP_ID || !APP_CERTIFICATE) {
    return new Response(
      JSON.stringify({
        error:
          "AGORA_APP_ID / AGORA_APP_CERTIFICATE secrets are not set on this function.",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    const body = await req.json();
    const channelName = body?.channelName as string | undefined;
    const uid = (body?.uid as number | undefined) ?? 0;

    if (!channelName) {
      return new Response(
        JSON.stringify({ error: "channelName is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const expirationInSeconds = 3600; // 1 hour - plenty for a consult call
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationInSeconds;

    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
    );

    return new Response(JSON.stringify({ token, appId: APP_ID }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
