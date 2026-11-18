// Local OpenCode plugin: inject mlx_lm.server /v1/models into provider.mlx.
// No npm deps — Boethiah blocks registry.npmjs.org.
// Static provider.mlx.models entries win on key collision (and by API id).

const PROVIDER = "mlx";
const DEFAULT_CONTEXT = 32768;
const DEFAULT_OUTPUT_CAP = 8192;
const FETCH_TIMEOUT_MS = 3000;

function maxOutput(context) {
  return Math.min(DEFAULT_OUTPUT_CAP, Math.max(1, Math.floor(context / 2)));
}

function shortKey(modelId) {
  const id = String(modelId);
  // Prefer HF repo folder name over snapshot hash for local cache paths.
  const hub = id.match(/models--([^/]+)\/snapshots\//);
  if (hub) return hub[1].replaceAll("--", "/").split("/").pop();
  const parts = id.split("/").filter(Boolean);
  return parts.length ? parts[parts.length - 1] : id;
}

function displayName(modelId) {
  return shortKey(modelId);
}

async function listRemoteModels(baseURL) {
  const url = new URL("models", baseURL.endsWith("/") ? baseURL : `${baseURL}/`);
  const res = await fetch(url, { signal: AbortSignal.timeout(FETCH_TIMEOUT_MS) });
  if (!res.ok) {
    throw new Error(`GET ${url} -> ${res.status}`);
  }
  const body = await res.json();
  const data = Array.isArray(body?.data) ? body.data : [];
  return data
    .map((entry) => entry?.id)
    .filter((id) => typeof id === "string" && id.length > 0)
    // Prefer HF repo ids; absolute --model paths are duplicates of cache entries.
    .filter((id) => !id.startsWith("/"));
}

function mergeDiscovered(existing, remoteIds) {
  const models = { ...(existing && typeof existing === "object" ? existing : {}) };
  const claimedIds = new Set(
    Object.values(models)
      .map((m) => (m && typeof m === "object" ? m.id : null))
      .filter((id) => typeof id === "string"),
  );
  const usedKeys = new Set(Object.keys(models));

  for (const id of remoteIds) {
    if (claimedIds.has(id)) continue;

    let key = shortKey(id);
    if (usedKeys.has(key)) {
      // Disambiguate e.g. owner/name collisions.
      key = id.replaceAll("/", "__");
    }
    if (usedKeys.has(key)) continue;

    const context = DEFAULT_CONTEXT;
    models[key] = {
      id,
      name: displayName(id),
      limit: {
        context,
        output: maxOutput(context),
      },
    };
    usedKeys.add(key);
    claimedIds.add(id);
  }

  return models;
}

export async function MlxModelsDiscoveryPlugin() {
  return {
    config: async (config) => {
      const provider = config?.provider?.[PROVIDER];
      if (!provider || typeof provider !== "object") return;

      const baseURL = provider.options?.baseURL;
      if (typeof baseURL !== "string" || !baseURL) return;

      try {
        const remoteIds = await listRemoteModels(baseURL);
        provider.models = mergeDiscovered(provider.models, remoteIds);
      } catch (err) {
        console.warn(
          `[mlx-models-discovery] failed to list models from ${baseURL}: ${err}`,
        );
      }
    },
  };
}

export default MlxModelsDiscoveryPlugin;
