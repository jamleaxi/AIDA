// Proxies chat requests to Gemini or Groq using server-side secrets so the
// provider API keys never ship inside the Flutter app.
//
// Deploy:   supabase functions deploy ai-chat
// Secrets:  supabase secrets set GEMINI_API_KEY=... GROQ_API_KEY=...
//
// Expects JSON body: { "provider": "gemini" | "groq", "message": string }
// Requires a valid Supabase auth JWT (enforced by the platform by default).

const SYSTEM_PROMPT =
  "You are AIDA, a friendly beginner tutor. Answer the user directly and " +
  "completely. Do not begin with a greeting, repeat the question, or " +
  "merely offer to help. Use plain language, short paragraphs, Markdown " +
  "formatting, and practical examples. Keep normal answers under 300 words.";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

class ProviderError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function callGemini(apiKey: string, message: string): Promise<string> {
  const model = "gemini-3.6-flash";
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": apiKey,
    },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ role: "user", parts: [{ text: message }] }],
      generationConfig: {
        maxOutputTokens: 2048,
        thinkingConfig: { thinkingLevel: "minimal" },
      },
    }),
  });

  const json = await response.json().catch(() => ({}));

  if (!response.ok) {
    const apiMessage = json?.error?.message;
    throw new ProviderError(
      typeof apiMessage === "string" && apiMessage.trim()
        ? apiMessage.trim()
        : "Gemini returned an error. Please try again.",
      response.status,
    );
  }

  const parts = json?.candidates?.[0]?.content?.parts;
  const text = Array.isArray(parts)
    ? parts
      .map((part: { text?: string }) => part?.text?.trim() ?? "")
      .filter((part: string) => part.length > 0)
      .join("\n")
    : "";

  if (!text) {
    throw new ProviderError(
      "Gemini returned an unexpected response. Please try again.",
      502,
    );
  }
  return text;
}

async function callGroq(apiKey: string, message: string): Promise<string> {
  const response = await fetch(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: message },
        ],
        temperature: 0.7,
        max_completion_tokens: 2048,
      }),
    },
  );

  const json = await response.json().catch(() => ({}));

  if (!response.ok) {
    const apiMessage = json?.error?.message ?? json?.message;
    throw new ProviderError(
      typeof apiMessage === "string" && apiMessage.trim()
        ? apiMessage.trim()
        : "Groq returned an error. Please try again.",
      response.status,
    );
  }

  const text = json?.choices?.[0]?.message?.content;
  if (typeof text !== "string" || !text.trim()) {
    throw new ProviderError(
      "Groq returned an unexpected response. Please try again.",
      502,
    );
  }
  return text.trim();
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: { provider?: string; message?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }

  const provider = payload.provider;
  const message = payload.message?.trim();

  if (provider !== "gemini" && provider !== "groq") {
    return jsonResponse(
      { error: 'provider must be "gemini" or "groq".' },
      400,
    );
  }
  if (!message) {
    return jsonResponse({ error: "Please enter a message first." }, 400);
  }

  const apiKey = provider === "gemini"
    ? Deno.env.get("GEMINI_API_KEY")
    : Deno.env.get("GROQ_API_KEY");

  if (!apiKey) {
    const label = provider === "gemini" ? "Gemini" : "Groq";
    return jsonResponse(
      { error: `${label} is not configured on the server.` },
      503,
    );
  }

  try {
    const reply = provider === "gemini"
      ? await callGemini(apiKey, message)
      : await callGroq(apiKey, message);
    return jsonResponse({ reply });
  } catch (error) {
    if (error instanceof ProviderError) {
      return jsonResponse({ error: error.message }, error.status);
    }
    console.error("ai-chat unexpected error", error);
    return jsonResponse(
      { error: "Could not reach the AI provider. Please try again." },
      502,
    );
  }
});
