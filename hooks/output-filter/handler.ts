import { appendFileSync, mkdirSync, existsSync, readFileSync } from "fs";
import { join, dirname } from "path";

/**
 * Output DLP filter — post-send detection of secrets in bot messages.
 *
 * This is a DETECTION layer (not prevention — message already sent).
 * Prevention = systemd BindPaths (bot can't read .env/.ssh).
 * Together = defense in depth.
 *
 * On detection:
 * 1. Logs incident to action-log.md
 * 2. Pushes alert message to user
 */

type HookEvent = {
  type: string;
  action: string;
  sessionKey: string;
  context: Record<string, unknown>;
  timestamp: Date;
  messages: string[];
};

// === PATTERN RULES ===

type Rule = {
  name: string;
  pattern: RegExp;
  severity: "critical" | "high" | "medium";
};

const RULES: Rule[] = [
  // API keys — known prefixes
  { name: "anthropic_api_key", pattern: /sk-ant-api\S{20,}/gi, severity: "critical" },
  { name: "anthropic_oauth",   pattern: /sk-ant-oat\S{20,}/gi, severity: "critical" },
  { name: "openai_key",        pattern: /sk-proj-\S{20,}/gi, severity: "critical" },
  { name: "openai_key_old",    pattern: /sk-[a-zA-Z0-9]{32,}/g, severity: "critical" },
  { name: "google_api_key",    pattern: /AIza[A-Za-z0-9_-]{35}/g, severity: "critical" },
  { name: "groq_key",          pattern: /gsk_[A-Za-z0-9]{20,}/g, severity: "critical" },
  { name: "github_token",      pattern: /gh[ps]_[A-Za-z0-9]{36,}/g, severity: "critical" },
  { name: "github_pat",        pattern: /github_pat_[A-Za-z0-9_]{20,}/g, severity: "critical" },
  { name: "telegram_token",    pattern: /\d{8,10}:[A-Za-z0-9_-]{35}/g, severity: "critical" },
  { name: "jwt_token",         pattern: /eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/g, severity: "high" },

  // Private keys
  { name: "private_key_pem",   pattern: /-----BEGIN\s+(RSA\s+|EC\s+|OPENSSH\s+|DSA\s+)?PRIVATE\s+KEY-----/gi, severity: "critical" },

  // Generic hex secrets (64-char hex = 256-bit key, common for tokens)
  { name: "hex_secret_256",    pattern: /\b[0-9a-f]{64}\b/gi, severity: "medium" },

  // Base64-encoded variants of known prefixes
  { name: "b64_anthropic",     pattern: /c2stYW50/g, severity: "high" },  // base64("sk-ant")
  { name: "b64_openai",        pattern: /c2stcHJvai/g, severity: "high" }, // base64("sk-proj")
  { name: "b64_aiza",          pattern: /QUl6YQ/g, severity: "high" },     // base64("AIza")
];

// === ENTROPY DETECTION ===

function shannonEntropy(s: string): number {
  const freq = new Map<string, number>();
  for (const c of s) {
    freq.set(c, (freq.get(c) ?? 0) + 1);
  }
  let entropy = 0;
  const len = s.length;
  for (const count of freq.values()) {
    const p = count / len;
    entropy -= p * Math.log2(p);
  }
  return entropy;
}

/**
 * Detect high-entropy strings that might be secrets.
 * Threshold: entropy > 4.0 for strings 20+ chars with mixed case/digits.
 */
function findHighEntropyStrings(text: string): string[] {
  const hits: string[] = [];
  // Match long alphanumeric+special strings (potential tokens)
  const tokenPattern = /[A-Za-z0-9_/+=-]{32,}/g;
  let match: RegExpExecArray | null;
  while ((match = tokenPattern.exec(text)) !== null) {
    const candidate = match[0];
    const entropy = shannonEntropy(candidate);
    // High-entropy (>4.0) + mixed character classes = likely secret
    if (entropy > 4.0) {
      const hasUpper = /[A-Z]/.test(candidate);
      const hasLower = /[a-z]/.test(candidate);
      const hasDigit = /[0-9]/.test(candidate);
      const classes = [hasUpper, hasLower, hasDigit].filter(Boolean).length;
      if (classes >= 2) {
        hits.push(candidate);
      }
    }
  }
  return hits;
}

// === KNOWN SECRETS FROM CONFIG ===

let knownSecrets: string[] = [];

function loadKnownSecrets(): void {
  try {
    // Load .env secrets
    const envPath = join(process.env.HOME ?? "", ".openclaw", ".env");
    if (existsSync(envPath)) {
      const envContent = readFileSync(envPath, "utf-8");
      for (const line of envContent.split("\n")) {
        const m = line.match(/^[A-Z_]+=(.+)/);
        if (m && m[1].length > 8) {
          knownSecrets.push(m[1].replace(/^["']|["']$/g, ""));
        }
      }
    }
  } catch {
    // Can't read .env — that's actually good (systemd BindPaths working)
  }

  try {
    // Load config secrets (botToken, gateway token)
    const cfgPath = join(process.env.HOME ?? "", ".openclaw", "openclaw.json");
    if (existsSync(cfgPath)) {
      const cfg = JSON.parse(readFileSync(cfgPath, "utf-8"));
      const botToken = cfg?.channels?.telegram?.botToken;
      if (botToken) knownSecrets.push(botToken);
      const gwToken = cfg?.gateway?.auth?.token;
      if (gwToken) knownSecrets.push(gwToken);
    }
  } catch {
    // ignore
  }

  // Dedupe and filter short strings
  knownSecrets = [...new Set(knownSecrets)].filter((s) => s.length > 8);
}

// Load on module init
loadKnownSecrets();

// === SCANNING ===

type Finding = {
  rule: string;
  severity: string;
  matchPreview: string;
};

function scanText(text: string): Finding[] {
  if (!text || text.length < 10) return [];

  const findings: Finding[] = [];

  // 1. Known exact secrets (substring match — catches partial leaks too)
  for (const secret of knownSecrets) {
    // Check both exact and partial (first/last 12+ chars)
    if (text.includes(secret)) {
      findings.push({
        rule: "known_secret_exact",
        severity: "critical",
        matchPreview: `${secret.slice(0, 6)}...${secret.slice(-4)} (len=${secret.length})`,
      });
    }
    // Partial: first 16 chars of secret appearing
    if (secret.length > 20) {
      const prefix = secret.slice(0, 16);
      const suffix = secret.slice(-16);
      if (text.includes(prefix) || text.includes(suffix)) {
        if (!text.includes(secret)) { // don't double-count
          findings.push({
            rule: "known_secret_partial",
            severity: "high",
            matchPreview: `partial match (len=${secret.length})`,
          });
        }
      }
    }
  }

  // 2. Regex patterns
  for (const rule of RULES) {
    rule.pattern.lastIndex = 0; // reset regex state
    const match = rule.pattern.exec(text);
    if (match) {
      const m = match[0];
      findings.push({
        rule: rule.name,
        severity: rule.severity,
        matchPreview: m.length > 16 ? `${m.slice(0, 8)}...${m.slice(-4)}` : m,
      });
    }
  }

  // 3. Entropy-based detection (catches unknown secrets)
  const entropyHits = findHighEntropyStrings(text);
  for (const hit of entropyHits) {
    // Skip if already caught by regex rules
    const alreadyCaught = findings.some((f) => hit.includes(f.matchPreview.split("...")[0]));
    if (!alreadyCaught) {
      findings.push({
        rule: "high_entropy_string",
        severity: "medium",
        matchPreview: `${hit.slice(0, 8)}...${hit.slice(-4)} (len=${hit.length}, entropy=${shannonEntropy(hit).toFixed(1)})`,
      });
    }
  }

  return findings;
}

// === LOGGING ===

function logIncident(findings: Finding[], text: string, event: HookEvent): void {
  const workspace = process.env.CLAWD_WORKSPACE ?? join(process.env.HOME ?? "", "clawd");
  const logPath = join(workspace, "action-log.md");

  const now = new Date().toISOString();
  const maxSeverity = findings.some((f) => f.severity === "critical")
    ? "CRITICAL"
    : findings.some((f) => f.severity === "high")
      ? "HIGH"
      : "MEDIUM";

  const entry = [
    "",
    `## [DLP-ALERT] ${now} — ${maxSeverity}`,
    "",
    `**session:** ${event.sessionKey}`,
    `**channel:** ${event.context.channel ?? "unknown"}`,
    `**target:** ${event.context.target ?? "unknown"}`,
    `**message length:** ${text.length}`,
    "",
    "**findings:**",
    ...findings.map((f) => `- \`${f.rule}\` [${f.severity}]: ${f.matchPreview}`),
    "",
    "---",
    "",
  ].join("\n");

  try {
    appendFileSync(logPath, entry);
  } catch (err) {
    console.error("[output-filter] Failed to write action-log:", err);
  }
}

// === HANDLER ===

export default async function handler(event: HookEvent): Promise<void> {
  // Only message:sent events
  if (event.type !== "message" || event.action !== "sent") return;

  const text = String(event.context.text ?? "");
  if (!text) return;

  const findings = scanText(text);

  if (findings.length === 0) return;

  // Filter: skip medium-only if message is short code/technical content
  const hasCriticalOrHigh = findings.some((f) => f.severity === "critical" || f.severity === "high");
  if (!hasCriticalOrHigh && text.length < 200) return;

  // Log incident
  logIncident(findings, text, event);

  // Alert via hook messages (user sees this in chat)
  const maxSeverity = findings.some((f) => f.severity === "critical") ? "CRITICAL" : "HIGH";
  const ruleNames = findings.map((f) => f.rule).join(", ");

  console.error(`[output-filter] DLP ALERT: ${maxSeverity} — rules: ${ruleNames}`);

  if (hasCriticalOrHigh) {
    event.messages.push(
      `⚠️ [DLP ALERT — ${maxSeverity}] potential secret detected in previous message. ` +
      `rules: ${ruleNames}. check action-log.md. consider revoking exposed credentials.`
    );
  }
}
