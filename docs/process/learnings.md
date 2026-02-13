# Learnings — Ошибки и выводы

Трекинг важных инцидентов и lessons learned.

**Критерий включения:**
- Downtime > 1 мин
- Data loss риск
- Повторяющийся паттерн (3+ раза)

---

## 2026-01-30: Opus config — Invalid field crash

**Что случилось:**
- Добавил `agents.defaults.model.allowlist` в конфиг
- Moltbot упал: "Unrecognized key: allowlist"
- Downtime: ~2 минуты (auto-restart loop)
- Откатился из бэкапа

**Root cause:**
- Угадал название поля вместо проверки docs
- Правильное поле: `agents.defaults.models` (не `allowlist`)

**Lesson learned:**
**📚 Documentation-first для незнакомых config полей**

```bash
# ❌ WRONG: guess and deploy
vim config.json  # добавил allowlist
ssh $SERVER && restart  # упало

# ✅ RIGHT: check docs first
# 1. Search docs
open https://docs.openclaw.ai/concepts/models

# 2. Find correct structure:
# agents.defaults.models = { "model-id": { alias: "Name" } }

# 3. Validate, then apply
```

**Process change:**
- Для config changes: всегда проверять docs/examples ПЕРЕД изменениями
- Если нет docs — тестировать локально или спросить

**Related:** ADR-011

---

## 2026-01-30: Config overwrite — Lost gateway auth

**Что случилось:**
- Deploy script перезаписал рабочий конфиг упрощённой версией
- Потеряли: `gateway.auth.token`, `env` section (API keys), `plugins`
- Бот перестал стартовать

**Root cause:**
- `deploy.sh` делал `envsubst` на локальном конфиге и заливал на сервер
- Локальный конфиг был неполный (только то что мы редактировали)
- Рабочий конфиг создаётся через `openclaw onboard` и содержит больше полей

**Lesson learned:**
**🚫 НИКОГДА не деплоить config**

Config живёт ТОЛЬКО на сервере:
- Создаётся: `openclaw onboard`
- Редактируется: вручную на сервере с бэкапом
- Reference: можем скачать через `sync.sh pull` для просмотра

**Process change:**
- Удалили config deploy из `deploy.sh`
- Создали ADR-010: "Конфиг на сервере — не деплоить"
- Добавили `.gitignore` для `config/moltbot-server.json` (reference only)

**Related:** ADR-010

---

## 2026-01-29: Skills `--delete` flag — Чуть не потеряли bot skills

**Что случилось:**
- `deploy.sh` использовал `rsync --delete`
- Это удаляло все skills на сервере, которых нет локально
- Бот сам создаёт skills — их нет в локальном repo
- Чуть не потеряли всю работу бота

**Root cause:**
- Не понимали что бот сам создаёт skills и они должны оставаться на сервере
- Использовали флаг `--delete` для "чистого" деплоя

**Lesson learned:**
**🤖 Уважать автономность бота**

Bot-owned files (SOUL.md, skills/, custom/, meta/):
- Бот сам создаёт и обновляет
- Деплоим ТОЛЬКО новые seed skills (`--ignore-existing`)
- Pull перед любыми изменениями

**Process change:**
- Изменили `sync.sh push` на `--ignore-existing` для skills
- Создали ownership model: READ-ONLY vs BOT OWNS
- Двунаправленный sync: pull before push

---

## Pattern: Production changes без валидации

**Повторяющаяся тема:**
1. Config overwrite → потеряли auth token
2. Skills --delete → чуть не потеряли bot skills
3. Opus allowlist → downtime 2 минуты

**Общий root cause:**
Изменения в production без проверки последствий.

**Meta-level fix:**
- **Backups before critical changes** (уже есть в scripts)
- **Pull before push** (уже в workflow)
- **Documentation-first** (новое правило)
- **Test locally when possible** (пока сложно для moltbot)

---

## Template для новых learnings

```markdown
## YYYY-MM-DD: Title

**Что случилось:**
- Описание инцидента
- Последствия

**Root cause:**
- Immediate причина
- Deeper причина
- Meta-level (если есть паттерн)

**Lesson learned:**
**Главный вывод одной строкой**

Детали...

**Process change:**
- Что изменили
- Как это предотвратит повтор

**Related:** ADR-XXX, другие learnings
```

---

## 2026-01-31: contextPruning.mode — Invalid input crash

**Что случилось:**
- Добавил `contextPruning: { mode: "adaptive" }` в конфиг
- Moltbot упал: "agents.defaults.contextPruning.mode: Invalid input"
- Downtime: ~2 минуты

**Root cause:**
- Опять угадал значение без проверки docs
- Документация WebFetch показала "adaptive" как опцию, но это было неточно
- Не проверил реальную schema

**Lesson learned:**
**📚 ЧЕТВЁРТЫЙ раз! Не угадывать config values!**

Pattern повторяется:
1. Config overwrite → потеряли auth token
2. Opus allowlist → crash
3. **contextPruning.mode → crash**

**Process change:**
- Перед добавлением нового поля в конфиг:
  1. Найти ТОЧНЫЙ пример в docs или существующих конфигах
  2. Или протестировать на dev/staging (которого нет)
  3. Или спросить у openclaw onboard

**Related:** ADR-011

---

---

## 2026-02-02: OAuth token expiry — Бот друга падал постоянно

**Что случилось:**
- Бот друга падал с `HTTP 401: OAuth token has expired`
- Восстанавливали из бэкапов — не помогало, все токены мёртвые
- Токены истекали через ~1 час

**Root cause:**
1. **Неправильный тип авторизации:** `--auth-choice oauth` создаёт токен с expiry (~1 час)
2. **Захардкоженный токен в systemd:** `openclaw-gateway.service` имел `Environment="ANTHROPIC_API_KEY=..."` — gateway игнорировал конфиг
3. **Два конфликтующих сервиса:** `moltbot.service` и `openclaw-gateway.service` дрались за порт

**Lesson learned:**
**🔑 Использовать `--auth-choice setup-token` если есть подписка Pro/Max**

| auth-choice | формат ключа | expiry | оплата | рекомендация |
|-------------|--------------|--------|--------|--------------|
| `setup-token` | `sk-ant-oat01-...` | нет | через подписку | ✅ если есть Pro/Max |
| `apiKey` | `sk-ant-api03-...` | нет | pay-per-token | 💸 дорого |
| `oauth` | `sk-ant-oat01-...` + refresh | ~1 час | через подписку | ❌ истекает, избегать |

**Process change:**
```bash
# ✅ ПРАВИЛЬНО — токен без expiry
openclaw onboard --auth-choice setup-token

# ❌ НЕПРАВИЛЬНО — токен истечёт через час
openclaw onboard  # по умолчанию может выбрать oauth
```

**Фиксы на сервере:**
1. Убрать `Environment="ANTHROPIC_API_KEY=..."` из `.config/systemd/user/openclaw-gateway.service`
2. Отключить дублирующий `moltbot.service` если есть `openclaw-gateway.service`
3. `systemctl --user daemon-reload`

**Related:** docs/FRIEND-START.md, docs/multi-tenant.md

---

## 2026-02-06: PII leak в public template repos

**Что случилось:**
- Reviewer нашёл usernames и telegram ID в public template repos
- openclaw-infra содержал real telegram id в test results
- openclaw-brain содержал bot usernames и другие PII
- SSH key `bot-arena-shared` был в docs (private repo, но всё равно риск)

**Root cause:**
- Template repos созданы копированием из private без sanitization
- Нет pre-commit проверки на PII/secrets
- Real test data использовалась как examples

**Lesson learned:**
1. **Template repos = public by design** — sanitize ВСЁ перед копированием
2. **Pre-commit hooks обязательны** — проверка на patterns (usernames, telegram IDs, API keys)
3. **Never commit private keys** — даже в private repos (git history сохраняется)
4. **Test data должна быть fake** — `OWNER_ID`, `@username`, не real values

**Process change:**
```bash
# Добавить pre-commit hook в repos
cp scripts/pre-commit-secrets-check.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Patterns для проверки:
# - sk-ant-*, gsk_*, AIzaSy* (API keys)
# - @username patterns
# - Telegram IDs (numeric)
# - PRIVATE KEY
# - Real IP addresses
```

**Fix applied:**
1. Sanitized openclaw-infra (RESULTS.md)
2. Sanitized openclaw-brain (removed incident logs)
3. Removed SSH key from docs/architecture-bot-arena.md
4. Created scripts/pre-commit-secrets-check.sh
5. Need to rotate SSH key bot-arena-shared

**Related:** docs/architecture-bot-arena.md, scripts/pre-commit-secrets-check.sh

---

**Автор:** owner & Claude
**Обновлено:** 2026-02-06
