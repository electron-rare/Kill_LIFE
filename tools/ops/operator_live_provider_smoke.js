#!/usr/bin/env node

const DEFAULT_CHAT_URL =
  process.env.MASCARADE_CHAT_URL || "http://localhost:3000/api/v1/chat/completions";
const DEFAULT_PROVIDERS_URL =
  process.env.MASCARADE_PROVIDERS_URL || "http://localhost:3000/api/agents/providers";
const DEFAULT_OUTPUT = "artifacts/operator_lane/live_provider_result.json";
const DEFAULT_PROMPT = "Summarise the current Kill_LIFE operator lane in one concise sentence.";
const DEFAULT_PROVIDER_PREFERENCE = ["apple-coreml", "openai", "ollama", "anthropic", "openrouter"];
const DEFAULT_MODELS = {
  "apple-coreml": "apple-coreml:qwen3.5-4b-onnx-q4f16",
  openai: "openai:gpt-4.1-mini",
  ollama: "ollama:qwen3.5:9b",
  anthropic: "anthropic:claude-3-5-haiku-latest",
  openrouter: "openrouter:openai/gpt-4.1-mini",
};

function utcNow() {
  return new Date().toISOString();
}

function parseArgs(argv) {
  const args = {
    chatUrl: DEFAULT_CHAT_URL,
    providersUrl: DEFAULT_PROVIDERS_URL,
    provider: (process.env.MASCARADE_OPERATOR_PROVIDER || "").trim(),
    model: (process.env.MASCARADE_OPERATOR_MODEL || "").trim(),
    prompt: DEFAULT_PROMPT,
    output: DEFAULT_OUTPUT,
    timeout: Number.parseFloat(process.env.MASCARADE_OPERATOR_TIMEOUT || "30"),
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    if (!arg.startsWith("--")) {
      continue;
    }
    if (next == null) {
      break;
    }
    switch (arg) {
      case "--chat-url":
        args.chatUrl = next;
        i += 1;
        break;
      case "--providers-url":
        args.providersUrl = next;
        i += 1;
        break;
      case "--provider":
        args.provider = next;
        i += 1;
        break;
      case "--model":
        args.model = next;
        i += 1;
        break;
      case "--prompt":
        args.prompt = next;
        i += 1;
        break;
      case "--output":
        args.output = next;
        i += 1;
        break;
      case "--timeout":
        args.timeout = Number.parseFloat(next);
        i += 1;
        break;
      default:
        break;
    }
  }
  if (!Number.isFinite(args.timeout) || args.timeout <= 0) {
    args.timeout = 30;
  }
  return args;
}

function authHeaders() {
  const apiKey =
    (process.env.MASCARADE_API_KEY ||
      process.env.CRAZY_LIFE_API_KEY ||
      process.env.KILL_LIFE_API_KEY ||
      "").trim();
  const headers = { "Content-Type": "application/json" };
  if (apiKey) {
    headers.Authorization = `Bearer ${apiKey}`;
  }
  return headers;
}

async function httpJson(url, options = {}) {
  const controller = new AbortController();
  const timeoutMs = Math.round((options.timeout || 30) * 1000);
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method: options.method || "GET",
      headers: authHeaders(),
      body: options.body == null ? undefined : JSON.stringify(options.body),
      signal: controller.signal,
    });
    const text = await response.text();
    let parsed = null;
    try {
      parsed = JSON.parse(text);
    } catch {}
    return { status: response.status, parsed, text };
  } finally {
    clearTimeout(timer);
  }
}

function chooseProvider(available, requested) {
  if (requested) {
    return requested;
  }
  const wanted = (process.env.MASCARADE_OPERATOR_PROVIDER_PREFERENCE || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  const preferred = wanted.length ? wanted : DEFAULT_PROVIDER_PREFERENCE;
  for (const provider of preferred) {
    if (available.includes(provider)) {
      return provider;
    }
  }
  return available[0] || "";
}

function chooseModel(provider, requested) {
  if (requested) {
    return requested;
  }
  const envDefault = (process.env.MASCARADE_DEFAULT_MODEL || "").trim();
  if (envDefault) {
    if (provider && !envDefault.includes(":")) {
      return `${provider}:${envDefault}`;
    }
    return envDefault;
  }
  return DEFAULT_MODELS[provider] || "";
}

function inferProviderFromModel(model) {
  const normalized = (model || "").trim().toLowerCase();
  if (!normalized) {
    return "";
  }
  if (normalized.includes(":")) {
    return normalized.split(":", 1)[0];
  }
  if (normalized.startsWith("claude")) {
    return "claude";
  }
  if (normalized.startsWith("gpt") || normalized.startsWith("o1") || normalized.startsWith("o3")) {
    return "openai";
  }
  if (normalized.startsWith("gemini")) {
    return "gemini";
  }
  if (normalized.startsWith("mistral")) {
    return "mistral";
  }
  return "";
}

async function writeOutput(path, payload) {
  const fs = await import("node:fs/promises");
  const pathModule = await import("node:path");
  await fs.mkdir(pathModule.dirname(path), { recursive: true });
  await fs.writeFile(path, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
}

function extractCompletion(body) {
  if (!body || typeof body !== "object") {
    return "";
  }
  const choices = body.choices;
  if (!Array.isArray(choices) || choices.length === 0) {
    return "";
  }
  const first = choices[0];
  if (!first || typeof first !== "object") {
    return "";
  }
  const message = first.message;
  if (!message || typeof message !== "object") {
    return "";
  }
  return typeof message.content === "string" ? message.content : "";
}

async function finish(code, result, output) {
  await writeOutput(output, result);
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(code);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const result = {
    generated_at: utcNow(),
    status: "blocked",
    execution_path: "live-provider",
    chat_url: args.chatUrl,
    providers_url: args.providersUrl,
    prompt: args.prompt,
    provider: "",
    model: "",
    available_providers: [],
    completion: "",
    summary: "",
    error: null,
    http_status: null,
    usage: null,
  };

  let providersResponse;
  try {
    providersResponse = await httpJson(args.providersUrl, { timeout: args.timeout });
  } catch (error) {
    result.status = "blocked";
    result.error = `providers lookup failed: ${error instanceof Error ? error.message : String(error)}`;
    await finish(4, result, args.output);
  }

  result.http_status = providersResponse.status;
  const available =
    providersResponse.parsed &&
    typeof providersResponse.parsed === "object" &&
    Array.isArray(providersResponse.parsed.providers)
      ? providersResponse.parsed.providers.filter((item) => typeof item === "string" && item.trim())
      : [];
  result.available_providers = available;

  const requestedProvider = args.provider.trim();
  const requestedModel = args.model.trim();
  let provider = requestedProvider || "";
  let model = requestedModel;
  result.provider = provider;
  result.model = model;

  if (providersResponse.status >= 400) {
    result.status = "degraded";
    result.error = `providers endpoint returned HTTP ${providersResponse.status}: ${
      providersResponse.text.trim() || "empty response"
    }`;
    await finish(3, result, args.output);
  }
  if (!requestedProvider && !requestedModel && available.length === 0) {
    result.status = "degraded";
    result.error = "no runtime provider is currently advertised by mascarade";
    await finish(3, result, args.output);
  }

  if (!provider && requestedModel) {
    provider = inferProviderFromModel(requestedModel);
    result.provider = provider;
  }

  let chatResponse;
  try {
    const body = {
      system: "You are a concise operations copilot.",
      messages: [
        { role: "user", content: args.prompt },
      ],
      temperature: 0.2,
      max_tokens: 160,
    };
    if (requestedModel && model) {
      body.model = model;
    }
    chatResponse = await httpJson(args.chatUrl, {
      method: "POST",
      body,
      timeout: args.timeout,
    });
  } catch (error) {
    result.status = "blocked";
    result.error = `chat request failed: ${error instanceof Error ? error.message : String(error)}`;
    await finish(4, result, args.output);
  }

  result.http_status = chatResponse.status;
  if (chatResponse.status >= 400) {
    result.status = "degraded";
    result.error = chatResponse.text.trim() || `chat endpoint returned HTTP ${chatResponse.status}`;
    await finish(3, result, args.output);
  }

  const completion = extractCompletion(chatResponse.parsed);
  if (!completion) {
    result.status = "degraded";
    result.error = "chat response did not contain a completion message";
    await finish(3, result, args.output);
  }

  result.status = "ready";
  result.completion = completion;
  result.summary = completion.trim() ? completion.split(/\r?\n/, 1)[0].trim() : "";
  if (chatResponse.parsed && typeof chatResponse.parsed === "object") {
    const bodyModel = typeof chatResponse.parsed.model === "string" ? chatResponse.parsed.model.trim() : "";
    if (bodyModel) {
      result.model = bodyModel;
      if (!result.provider) {
        result.provider = inferProviderFromModel(bodyModel);
      }
    }
    if (chatResponse.parsed.usage && typeof chatResponse.parsed.usage === "object") {
      result.usage = chatResponse.parsed.usage;
    }
  }

  await finish(0, result, args.output);
}

main().catch(async (error) => {
  const result = {
    generated_at: utcNow(),
    status: "blocked",
    execution_path: "live-provider",
    error: error instanceof Error ? error.message : String(error),
  };
  await writeOutput(DEFAULT_OUTPUT, result);
  process.stdout.write(`${JSON.stringify(result)}\n`);
  process.exit(4);
});
