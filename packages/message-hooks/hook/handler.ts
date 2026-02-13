import { appendFileSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";

type MessageEvent = {
  type: "message";
  action: "received" | "sent" | "preprocessed";
  sessionKey: string;
  context: Record<string, unknown>;
};

/**
 * Normalize chatId to a consistent numeric form.
 * received events may have groupId like "telegram:group:-100XXXXXXXXXX"
 * sent events may have target like "-100XXXXXXXXXX"
 * We strip the channel prefix to get a stable directory path.
 */
function normalizeChatId(raw: string): string {
  // "telegram:group:-100XXXXXXXXXX" → "-100XXXXXXXXXX"
  const match = raw.match(/:(-?\d+)$/);
  if (match) return match[1];
  return raw;
}

export default async function handler(event: MessageEvent): Promise<void> {
  if (event.type \!== "message") return;

  const now = new Date();
  const channel = String(event.context.channel ?? "unknown");

  let chatId: string;
  if (event.action === "sent") {
    chatId = String(event.context.groupId ?? event.context.target ?? "dm");
  } else {
    // received + preprocessed both use senderId/groupId
    chatId = String(event.context.groupId ?? event.context.senderId ?? "dm");
  }
  chatId = normalizeChatId(chatId);

  const logPath = join(
    process.env.CLAWD_WORKSPACE ?? ".",
    "raw",
    channel,
    "chats",
    chatId,
    String(now.getFullYear()),
    String(now.getMonth() + 1).padStart(2, "0"),
    `${String(now.getDate()).padStart(2, "0")}.jsonl`
  );

  try {
    const dir = dirname(logPath);
    if (\!existsSync(dir)) mkdirSync(dir, { recursive: true });

    appendFileSync(logPath, JSON.stringify({
      ts: Date.now(),
      action: event.action,
      session: event.sessionKey,
      ...event.context,
    }) + "\n");

  } catch (err) {
    console.error("[memory-logger] error:", err);
  }
}
