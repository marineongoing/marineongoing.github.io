import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
    });
    const { data: { user } } = await sb.auth.getUser();
    if (!user || user.email !== Deno.env.get("ALLOWED_EMAIL")) return json({ error: "not_allowed" }, 403);

    const { messages, max_tokens, stream } = await req.json();
    if (!Array.isArray(messages) || !messages.length) return json({ error: "bad_request" }, 400);

    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({ model: "claude-sonnet-5", max_tokens: Math.min(max_tokens || 2000, 12000), messages, ...(stream ? { stream: true } : {}) }),
    });
    // stream: true (Study) : on renvoie la réponse au fur et à mesure, pour que les longues réponses ne soient pas coupées
    if (stream && r.ok && r.body) {
      return new Response(r.body, { headers: { ...cors, "Content-Type": "text/event-stream", "Cache-Control": "no-cache" } });
    }
    return json(await r.json(), r.status);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
