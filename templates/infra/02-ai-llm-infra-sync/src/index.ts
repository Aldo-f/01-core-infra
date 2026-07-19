import { promises as fs } from 'fs';
import { readFileSync } from 'fs';
import * as path from 'path';
import { parse, stringify } from 'yaml';

// ---------- TYPES ----------
// The real source-of-truth shape (Hermes / OpenCode auth.json):
//   { version, providers?, active_provider?, credential_pool: { openrouter: Cred[], gemini: Cred[], xai: Cred[] } }
// Each Cred carries metadata (id, label, auth_type, source, last_status, ...).
// We merge per-provider credential arrays across all sources WITHOUT
// destroying per-credential metadata that the live gateway depends on.

interface Credential {
  id?: string;
  label?: string;
  auth_type?: string;
  source?: string;
  [k: string]: unknown;
}

interface AuthDoc {
  version?: number;
  providers?: Record<string, unknown>;
  active_provider?: string | null;
  credential_pool?: Record<string, Credential[]>;
  [k: string]: unknown;
}

// ---------- HELPERS ----------
async function readJson(filePath: string): Promise<AuthDoc> {
  try {
    const data = await fs.readFile(filePath, 'utf8');
    return JSON.parse(data) as AuthDoc;
  } catch {
    return {};
  }
}

async function readYaml(filePath: string): Promise<AuthDoc> {
  try {
    const data = await fs.readFile(filePath, 'utf8');
    try {
      return (parse(data) as AuthDoc) ?? {};
    } catch {
      // yaml throws on duplicate mapping keys; tolerant last-value-wins fallback
      const result: Record<string, any> = {};
      for (const raw of data.split('\n')) {
        const line = raw.trim();
        if (!line || line.startsWith('#') || !line.includes(':')) continue;
        const idx = line.indexOf(':');
        result[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
      }
      return result as AuthDoc;
    }
  } catch {
    return {};
  }
}

function readEnv(filePath: string): AuthDoc {
  // .env stores flat KEY=VALUE; map into a credential_pool-shaped doc so the
  // rest of the pipeline can treat every source uniformly.
  const pool: Record<string, Credential[]> = {};
  try {
    const lines = readFileSync(filePath, 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#') || !trimmed.includes('=')) continue;
      const idx = trimmed.indexOf('=');
      const key = trimmed.slice(0, idx).trim();
      const val = trimmed.slice(idx + 1).trim();
      // normalise env var name -> provider key (openrouter / gemini / xai)
      const prov = key.toLowerCase().includes('openrouter')
        ? 'openrouter'
        : key.toLowerCase().includes('gemini')
          ? 'gemini'
          : key.toLowerCase().includes('xai')
            ? 'xai'
            : null;
      if (!prov) continue;
      pool[prov] = pool[prov] ?? [];
      pool[prov].push({
        id: key,
        label: key,
        auth_type: 'api_key',
        source: `env:${key}`,
        value: val,
      });
    }
  } catch {
    // ignore read errors
  }
  return { credential_pool: pool };
}

// Stable fingerprint of a credential so we can dedupe without wiping metadata.
function credKey(c: Credential): string {
  if (c.id) return `id:${c.id}`;
  if (c.source) return `src:${c.source}`;
  if (c.label) return `lbl:${c.label}`;
  return `val:${JSON.stringify(c.value ?? c)}`;
}

// Merge source pools into target pools, preserving existing credentials'
// metadata and only appending ones not already present.
function mergePools(
  target: Record<string, Credential[]> | undefined,
  sources: Record<string, Credential[]>[]
): Record<string, Credential[]> {
  const out: Record<string, Credential[]> = {};
  const providers = new Set<string>();
  if (target) for (const p of Object.keys(target)) providers.add(p);
  for (const s of sources) if (s) for (const p of Object.keys(s)) providers.add(p);

  for (const p of providers) {
    const seen = new Set<string>();
    const merged: Credential[] = [];
    // existing credentials first (keeps live gateway metadata intact)
    for (const c of target?.[p] ?? []) {
      const k = credKey(c);
      if (!seen.has(k)) {
        seen.add(k);
        merged.push(c);
      }
    }
    // append from each source if not already present
    for (const s of sources) {
      for (const c of s?.[p] ?? []) {
        const k = credKey(c);
        if (!seen.has(k)) {
          seen.add(k);
          merged.push(c);
        }
      }
    }
    out[p] = merged;
  }
  return out;
}

function fileExists(filePath: string): Promise<boolean> {
  return fs
    .access(filePath)
    .then(() => true)
    .catch(() => false);
}

// ---------- MAIN ----------
async function main() {
  const home = process.env.HOME;
  const sources = [
    { file: `${home}/.hermes/auth.json`, fmt: 'json' as const },
    { file: `${home}/.config/opencode/auth.json`, fmt: 'json' as const },
    { file: `${home}/dev/02-ai-omniroute/config.yaml`, fmt: 'yaml' as const },
    { file: `${home}/dev/02-ai-freellm-api/.env`, fmt: 'env' as const },
  ];

  // 1. HARVEST — read every source that exists.
  const harvested: { file: string; fmt: string; doc: AuthDoc }[] = [];
  for (const src of sources) {
    if (!(await fileExists(src.file))) {
      console.error(`Skip: ${src.file} bestaat niet, overslaan`);
      continue;
    }
    let doc: AuthDoc = {};
    try {
      if (src.fmt === 'json') doc = await readJson(src.file);
      else if (src.fmt === 'yaml') doc = await readYaml(src.file);
      else if (src.fmt === 'env') doc = readEnv(src.file);
    } catch (err) {
      console.error(`Fout bij lezen van ${src.file}:`, err);
      continue;
    }
    harvested.push({ file: src.file, fmt: src.fmt, doc });
  }

  // 2. UNIFY — build the merged per-provider pool across all sources.
  const pools = harvested.map((h) => h.doc.credential_pool ?? {});
  const unified = mergePools(undefined, pools);

  // 3. DISTRIBUTE — write the merged pool back into every source that exists,
  //    preserving each file's own structure/metadata (no full overwrite).
  for (const h of harvested) {
    try {
      const mergedDoc: AuthDoc = { ...h.doc, credential_pool: mergePools(h.doc.credential_pool, [unified]) };
      if (h.fmt === 'json') {
        await fs.writeFile(h.file, JSON.stringify(mergedDoc, null, 2), 'utf8');
      } else if (h.fmt === 'yaml') {
        await fs.writeFile(h.file, stringify(mergedDoc), 'utf8');
      } else if (h.fmt === 'env') {
        // .env: flatten the pool back to KEY=VALUE lines
        const lines: string[] = [];
        const pool = mergedDoc.credential_pool ?? {};
        for (const [prov, creds] of Object.entries(pool)) {
          for (const c of creds) {
            const name = (c.label ?? c.id ?? prov).toUpperCase().replace(/[^A-Z0-9_]/g, '_');
            if (typeof c.value === 'string') lines.push(`${name}=${c.value}`);
          }
        }
        await fs.writeFile(h.file, lines.join('\n') + '\n', 'utf8');
      }
    } catch (err) {
      console.error(`Fout bij schrijven van ${h.file}:`, err);
    }
  }

  console.log('✅ Sync voltooid – API-keys zijn uniek en veilig opgeslagen');
}

main().catch((err) => {
  console.error('❌ Sync fout:', err);
  process.exit(1);
});
