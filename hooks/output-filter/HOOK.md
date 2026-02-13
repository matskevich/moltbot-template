---
name: output-filter
description: "DLP: detect and alert on secrets leaked in outgoing messages"
metadata:
  {
    "openclaw":
      {
        "emoji": "🛡️",
        "events": ["message:sent"],
      },
  }
---

# output-filter (DLP)

post-send detection layer for secrets in bot messages.

## defense model

three layers (defense in depth):
1. **SECURITY.md** — prompt-level rules (soft, bypassable)
2. **systemd BindPaths** — prevention (bot can't read .env/.ssh)
3. **this hook** — detection (catches secrets from config, entropy-based unknown secrets)

## detection methods

1. **known secrets** — loads actual values from .env and config, substring match (catches partials)
2. **regex patterns** — known API key formats (anthropic, openai, google, github, telegram, jwt, PEM keys)
3. **base64 variants** — detects base64-encoded prefixes of known key types
4. **entropy-based** — Shannon entropy > 4.0 on 32+ char strings with mixed character classes
5. **hex secrets** — 64-char hex strings (256-bit tokens)

## on detection

- logs to `~/clawd/action-log.md` with severity, rules, session, channel
- pushes alert message to chat
- stderr log for journalctl

## limitations

- **post-send**: message already delivered. this is detection, not prevention
- **partial leaks across messages**: can only scan per-message, not cross-message
- **novel formats**: entropy catches most, but clever encoding may evade

## severity levels

- **critical**: exact known secret, known API key prefix patterns
- **high**: partial known secret match, JWT, base64-encoded key prefixes
- **medium**: high-entropy strings (unknown potential secrets)
