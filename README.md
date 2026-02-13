# openclaw-infra

Шаблон для personal AI assistant в Telegram. Память, навыки, полный контроль — на твоём сервере.

## Что это

- Telegram-бот через Claude (Anthropic)
- Persistent memory (Gemini embeddings — бесплатно)
- Живёт на твоём VPS — данные не утекают
- Развивается: создаёт навыки, формирует личность

## Quick Start

Открой Claude Code и вставь:

```
git clone https://github.com/matskevich/openclaw-infra.git my-moltbot
cd my-moltbot
```

Потом читай `FRIEND-START.md` — Claude Code проведёт через весь setup.

## Стоимость

| Сервис | Цена |
|--------|------|
| VPS (Hetzner CX22) | ~€4/мес |
| Claude API | $5-20/мес (ставь spending limit!) |
| Gemini (память) | бесплатно |
| Telegram бот | бесплатно |

## Структура

```
FRIEND-START.md           # Сценарий setup (для Claude Code)
SETUP.md                  # Техническая инструкция
CLAUDE.md.template        # Шаблон инструкций для твоего Claude Code
.env.example              # Пример переменных окружения
scripts/                  # safe-push, sync, secret detection
prompts/                  # AGENTS.md, SECURITY.md — инструкции боту
docs/process/learnings.md # Критические ошибки (читать обязательно!)
```

## Два репозитория

После setup у тебя будет ДВА репо:

| Репо | Кто владеет | Что внутри |
|------|-------------|------------|
| my-moltbot | ты | scripts, prompts, docs |
| my-moltbot-memory | бот | SOUL.md, skills/, memory/ |

Подробнее в `SETUP.md`.

## Безопасность

- API ключи только в `~/.openclaw/.env` на сервере (chmod 600)
- Pre-commit hooks блокируют коммиты с секретами
- ПЕРВЫМ ДЕЛОМ настрой spending limits на API ключи
- **[Exec sandbox playbook](docs/security/exec-sandbox-playbook.md)** — закрыть arbitrary code execution (20 мин)
- **[Security overview](docs/security/)** — defense-in-depth architecture (5 layers)
- Подробнее: `prompts/SECURITY.md`

## Docs

- [docs.openclaw.ai](https://docs.openclaw.ai) — документация openclaw
