import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Validate the Supabase anon key so random callers can't hit this function
  const apiKey = req.headers.get("apikey") ?? req.headers.get("authorization")?.replace("Bearer ", "");
  const expectedKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (expectedKey && apiKey !== expectedKey) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const { amount, currency = "INR", receipt, notes } = await req.json();

    if (!amount || typeof amount !== "number" || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid amount. Must be a positive number (in paise)." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Razorpay credentials — set these in Supabase Dashboard → Edge Functions → Secrets
    // RAZORPAY_KEY_ID   = rzp_test_xxxxx or rzp_live_xxxxx
    // RAZORPAY_KEY_SECRET = your secret key
    const keyId = Deno.env.get("RAZORPAY_KEY_ID");
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");

    if (!keyId || !keySecret) {
      console.error("Razorpay credentials not configured");
      return new Response(
        JSON.stringify({ error: "Payment gateway not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Base64-encode Key ID:Key Secret for Basic Auth
    const credentials = btoa(`${keyId}:${keySecret}`);

    const orderPayload: Record<string, unknown> = {
      amount,       // in paise (e.g., ₹100 = 10000)
      currency,
      receipt: receipt ?? `rcpt_${Date.now()}`,
    };

    if (notes && typeof notes === "object") {
      orderPayload.notes = notes;
    }

    const razorpayRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Basic ${credentials}`,
      },
      body: JSON.stringify(orderPayload),
    });

    const data = await razorpayRes.json();

    if (!razorpayRes.ok) {
      console.error("Razorpay API error:", data);
      return new Response(
        JSON.stringify({
          error: data?.error?.description ?? "Failed to create order",
        }),
        {
          status: razorpayRes.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Return the Razorpay order object — Flutter needs `id` (order_id)
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
