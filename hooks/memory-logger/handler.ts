/**
 * memory-logger hook
 *
 * writes all messages to raw log (layer 1 of ufc architecture)
 * raw = canonical truth, append-only, no decisions
 */

import { appendFileSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";

type MessageEvent = {
  type: "message";
  action: "received" | "sent" | "preprocessed";
  sessionKey: string;
  context: {
    // received
    message?: string;
    senderId?: string;
    senderName?: string;
    channel?: string;
    messageId?: string;
    isGroup?: boolean;
    groupId?: string;
    timestamp?: number;
    // sent
    text?: string;
    mediaUrl?: string;
    target?: string;
    kind?: string;
    // preprocessed
    rawBody?: string;
    processedBody?: string;
    transcript?: string;
    mediaOutputs?: Array<{ kind: string; text: string }>;
  };
};

function getLogPath(event: MessageEvent): string {
  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");

  const channel = event.context.channel ?? "unknown";
  const chatId = event.context.groupId ?? event.context.target ?? "dm";

  // telegram/raw/chats/<id>/YYYY/MM/DD.jsonl
  return join(
    process.env.CLAWD_WORKSPACE ?? ".",
    "raw",
    channel,
    "chats",
    String(chatId),
    String(yyyy),
    mm,
    `${dd}.jsonl`
  );
}

function ensureDir(filePath: string): void {
  const dir = dirname(filePath);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

export default async function handler(event: MessageEvent): Promise<void> {
  if (event.type !== "message") return;

  const logPath = getLogPath(event);
  ensureDir(logPath);

  const record = {
    ts: Date.now(),
    action: event.action,
    session: event.sessionKey,
    ...event.context,
  };

  appendFileSync(logPath, JSON.stringify(record) + "\n");
}
