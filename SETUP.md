# Moltbot Setup Guide

Инструкция для Claude Code агента по развёртыванию личного AI-ассистента Moltbot.

**Время:** ~30 минут
**Результат:** Работающий Telegram-бот с persistent memory на твоём VPS

---

## Архитектура

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ТВОЙ БУДУЩИЙ СЕТАП                              │
│                                                                         │
│   GitHub (твои репо):                                                   │
│   ├── my-moltbot           ← инфраструктура (этот репо)                 │
│   └── my-bot-memory    ← работа бота (создастся на сервере)         │
│                                                                         │
│   VPS (Hetzner/etc):                                                    │
│   ├── ~/clawd/             ← workspace бота                             │
│   ├── ~/.openclaw/         ← конфиг с API ключами                       │
│   └── moltbot.service      ← systemd сервис                             │
│                                                                         │
│   Telegram:                                                             │
│   └── @YourBot             ← твой бот через @BotFather                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Два репозитория — зачем?**
- `my-moltbot` — ты контролируешь: scripts, prompts, docs
- `my-bot-memory` — бот контролирует: его память, skills, личность

---

## Архитектура двух Git репозиториев

Это важно понять перед началом:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           ДВА НЕЗАВИСИМЫХ РЕПО                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  REPO 1: my-moltbot (инфраструктура)         Где: локально + GitHub          │
│  ════════════════════════════════════                                        │
│  Владелец: ТЫ                                                                │
│                                                                              │
│  Содержимое:                                                                 │
│  ├── scripts/sync.sh      # Скрипты деплоя                                   │
│  ├── prompts/AGENTS.md    # Системные инструкции боту                        │
│  ├── prompts/SECURITY.md  # Политики безопасности                            │
│  ├── docs/                # Твоя документация                                │
│  ├── CLAUDE.md            # Инструкции для Claude Code                       │
│  └── .env                 # Секреты (НЕ коммитить!)                          │
│                                                                              │
│  Workflow: редактируешь локально → git push → sync.sh push на сервер         │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  REPO 2: my-bot-memory (мозг бота)       Где: сервер ~/clawd/ + GitHub   │
│  ═════════════════════════════════════                                       │
│  Владелец: БОТ                                                               │
│                                                                              │
│  Содержимое:                                                                 │
│  ├── SOUL.md              # Личность бота (он сам формирует)                 │
│  ├── USER.md              # Заметки о тебе (он сам пишет)                    │
│  ├── skills/              # Навыки бота (он создаёт новые)                   │
│  ├── memory/              # Долгосрочная память (embeddings)                 │
│  ├── custom/              # Его заметки, исследования                        │
│  └── artifacts/           # Созданные файлы                                  │
│                                                                              │
│  Workflow: бот работает → меняет файлы → cron auto-commit → GitHub           │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Ownership Model — кто что контролирует

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FILE OWNERSHIP                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ТЫ КОНТРОЛИРУЕШЬ:                    БОТ КОНТРОЛИРУЕТ:                     │
│  ─────────────────                    ─────────────────                     │
│  • AGENTS.md (инструкции)             • SOUL.md (личность)                  │
│  • SECURITY.md (политики)             • USER.md (заметки о тебе)            │
│  • scripts/                           • skills/* (его навыки)               │
│  • docs/                              • memory/* (его память)               │
│  • .env (секреты)                     • custom/* (его файлы)                │
│                                                                             │
│  sync.sh push → ПЕРЕЗАПИСЫВАЕТ        sync.sh push → --ignore-existing      │
│  (твои файлы главнее)                 (не трогает работу бота)              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Sync Flow

```
         LOCAL (my-moltbot/)                    SERVER (~/clawd/)
         ═══════════════════                    ═════════════════

    ┌─────────────────────────┐            ┌─────────────────────────┐
    │  prompts/AGENTS.md      │───push────►│  AGENTS.md              │
    │  prompts/SECURITY.md    │───push────►│  SECURITY.md            │
    └─────────────────────────┘            └─────────────────────────┘

    ┌─────────────────────────┐            ┌─────────────────────────┐
    │  prompts/SOUL.md (copy) │◄───pull────│  SOUL.md                │
    │  prompts/USER.md (copy) │◄───pull────│  USER.md                │
    │  skills-server/ (copy)  │◄───pull────│  skills/                │
    └─────────────────────────┘            └─────────────────────────┘

    pull = скачать работу бота (для review, backup)
    push = отправить твои изменения на сервер
```

### Почему так?

1. **Бот автономен** — он развивает свою личность, создаёт skills, помнит контекст
2. **Ты контролируешь границы** — через AGENTS.md и SECURITY.md задаёшь правила
3. **Разделение ответственности** — не перезаписываем работу друг друга
4. **Backup** — оба репо на GitHub, ничего не потеряется

---

## Prerequisites

Перед началом нужно подготовить:

### 1. VPS сервер
- **Рекомендация:** Hetzner CX22 (~€4/мес) — 2 vCPU, 4GB RAM
- **ОС:** Ubuntu 22.04 или Debian 12
- **SSH доступ:** настроенный SSH ключ

### 2. API ключи
| Сервис | Зачем | Где взять |
|--------|-------|-----------|
| Anthropic | Основной LLM | https://console.anthropic.com |
| Gemini | Embeddings для memory (БЕСПЛАТНО) | https://aistudio.google.com/apikey |
| Telegram Bot | Общение | @BotFather в Telegram |

### 3. GitHub
- Аккаунт с возможностью создавать приватные репо
- SSH ключ настроен

### 4. Твой Telegram ID
Узнать: напиши любому боту @userinfobot или @getmyid_bot

---

## Безопасность API ключей

**ВАЖНО:** API ключи = деньги. Утечка может стоить сотни долларов.

### Правила

1. **НИКОГДА не коммить `.env`** — он в `.gitignore`, но проверяй
2. **Не отправлять ключи в чаты** — даже "временно"
3. **Ограничивать ключи** где возможно

### Как ограничить каждый ключ

| Ключ | Ограничения | Где настроить |
|------|-------------|---------------|
| **Anthropic** | Spending limit ($5-50/мес для начала) | console.anthropic.com → Settings → Limits |
| **Gemini** | IP restriction + только Generative Language API | console.cloud.google.com → APIs & Services → Credentials |
| **Telegram** | Нельзя ограничить | Просто храни в секрете |

### Настройка Gemini (рекомендуется)

```
1. console.cloud.google.com → выбрать проект
2. APIs & Services → Credentials → нажать на ключ
3. Application restrictions → IP addresses → добавить IP сервера
4. API restrictions → Restrict key → только "Generative Language API"
```

### Если ключ утёк

1. **Немедленно отзови** старый ключ в консоли провайдера
2. **Создай новый** ключ
3. **Обнови на сервере:**
   ```bash
   ssh moltbot@SERVER_IP
   nano ~/.openclaw/openclaw.json  # обновить ключ в секции env
   systemctl --user restart moltbot
   ```
4. **Проверь usage** в консоли провайдера на подозрительную активность
5. **Если есть charges** — напиши в support провайдера

### Признаки утечки

- Неожиданные charges в billing
- Ошибки rate limit когда ты не пользуешься
- Странные запросы в логах

---

## Шаг 1: Клонирование и отвязка

```bash
# Клонируем шаблон
git clone https://github.com/matskevich/openclaw-infra.git my-moltbot
cd my-moltbot

# Удаляем связь с оригиналом
rm -rf .git

# Создаём свой репозиторий
git init
git add -A
git commit -m "Initial: moltbot setup from template"

# Создай репо на GitHub: https://github.com/new
# Имя: my-moltbot (или любое другое)
# Private: да

# Подключаем свой remote
git remote add origin git@github.com:YOUR_USERNAME/my-moltbot.git
git push -u origin main
```

---

## Шаг 2: Настройка .env

```bash
cp .env.example .env
```

Заполни `.env`:
```bash
# Сервер
HETZNER_IP=YOUR_SERVER_IP
HETZNER_USER=moltbot

# API ключи (будут на сервере, тут для reference)
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AIzaSy...
TELEGRAM_BOT_TOKEN=1234567890:ABC...

# Твой Telegram ID (для авторизации)
TELEGRAM_USER_ID=123456789
```

**ВАЖНО:** `.env` в `.gitignore` — никогда не коммить!

---

## Шаг 3: Подготовка сервера

SSH на сервер и выполни:

```bash
ssh root@YOUR_SERVER_IP
```

### 3.1 Создание пользователя moltbot

```bash
# Создаём пользователя
adduser moltbot --disabled-password --gecos ""

# Даём sudo (опционально)
usermod -aG sudo moltbot

# Копируем SSH ключ
mkdir -p /home/moltbot/.ssh
cp ~/.ssh/authorized_keys /home/moltbot/.ssh/
chown -R moltbot:moltbot /home/moltbot/.ssh
chmod 700 /home/moltbot/.ssh
chmod 600 /home/moltbot/.ssh/authorized_keys

# Разрешаем lingering (чтобы systemd user services работали)
loginctl enable-linger moltbot
```

### 3.2 Установка зависимостей

```bash
apt update && apt install -y curl git python3 python3-pip

# Устанавливаем openclaw CLI
npm install -g openclaw

# Проверяем
openclaw --version
```

### 3.3 Переключаемся на moltbot

```bash
su - moltbot
```

---

## Шаг 4: Инициализация Moltbot

На сервере под пользователем `moltbot`:

```bash
# Создаём workspace
mkdir -p ~/clawd
cd ~/clawd

# Запускаем wizard
npx openclaw onboard
```

Wizard спросит:
1. **Anthropic API key** — вставь свой
2. **Telegram bot token** — от @BotFather
3. **Allowed users** — твой Telegram ID

После wizard создастся `~/.openclaw/openclaw.json` с конфигом.

---

## Шаг 5: Добавление Gemini для embeddings (БЕСПЛАТНО)

```bash
# Открываем конфиг
nano ~/.openclaw/openclaw.json
```

Найди секцию `"env"` и добавь Gemini ключ:
```json
"env": {
  "ANTHROPIC_API_KEY": "...",
  "GEMINI_API_KEY": "AIzaSy..."
}
```

Найди или создай секцию `agents.defaults.memorySearch`:
```json
"agents": {
  "defaults": {
    "memorySearch": {
      "provider": "gemini",
      "model": "gemini-embedding-001",
      "query": {
        "hybrid": {
          "enabled": true,
          "vectorWeight": 0.7,
          "textWeight": 0.3
        }
      },
      "sources": ["memory", "sessions"],
      "cache": {
        "enabled": true,
        "maxEntries": 50000
      },
      "experimental": {
        "sessionMemory": true
      }
    },
    "compaction": {
      "reserveTokensFloor": 50000,
      "memoryFlush": {
        "enabled": true,
        "softThresholdTokens": 4000
      }
    }
  }
}
```

**Что это даёт:**
- **hybrid search** — 70% vector + 30% text matching для лучших результатов
- **sessionMemory** — индексирует ВСЮ переписку, не только явные сохранения
- **cache** — ускоряет повторные запросы
- **memoryFlush** — автоматически сохраняет важное перед compaction

**ВАЖНО:** Не угадывай поля конфига! Проверяй в docs: https://docs.openclaw.ai

---

## Шаг 6: Systemd сервис

```bash
# Создаём директорию для user services
mkdir -p ~/.config/systemd/user

# Создаём сервис
cat > ~/.config/systemd/user/moltbot.service << 'EOF'
[Unit]
Description=Moltbot Gateway
After=network.target

[Service]
Type=simple
ExecStart=/home/moltbot/.local/bin/openclaw
Restart=always
RestartSec=5
WorkingDirectory=/home/moltbot/clawd

[Install]
WantedBy=default.target
EOF

# Включаем и запускаем
systemctl --user daemon-reload
systemctl --user enable moltbot
systemctl --user start moltbot

# Проверяем
systemctl --user status moltbot
```

---

## Шаг 7: Проверка

```bash
# Логи
journalctl --user -u moltbot -f
```

Должен увидеть:
```
[gateway] listening on ws://127.0.0.1:18789
[telegram] starting provider (@YourBot)
```

**Теперь напиши боту в Telegram!** Он должен ответить.

---

## Шаг 8: Git для памяти бота

На сервере создаём репо для работы бота:

```bash
cd ~/clawd

# Инициализируем git
git init
git add -A
git commit -m "Initial: bot workspace"

# Создай репо на GitHub: my-bot-memory (private)
git remote add origin git@github.com:YOUR_USERNAME/my-bot-memory.git
git push -u origin main
```

### Автокоммит (cron)

```bash
crontab -e
```

Добавь:
```cron
0 */6 * * * cd ~/clawd && git add -A && git commit -m "Auto-backup: $(date +\%Y-\%m-\%d\ \%H:\%M)" && git push || true
```

Это будет коммитить работу бота каждые 6 часов.

---

## Шаг 9: Настройка локального sync

На своём компьютере в `my-moltbot/`:

```bash
# Проверь что .env заполнен
cat .env

# Протестируй подключение
ssh moltbot@YOUR_SERVER_IP "systemctl --user status moltbot"

# Сделай первый pull (получить что бот создал)
./scripts/sync.sh pull
```

---

## Структура файлов

После setup у тебя будет:

**Локально (my-moltbot/):**
```
├── .env                    # Твои секреты (не коммитить!)
├── CLAUDE.md               # Инструкции для Claude Code
├── scripts/
│   └── sync.sh             # Синхронизация с сервером
├── prompts/
│   ├── AGENTS.md           # Системные инструкции боту
│   └── SECURITY.md         # Политики безопасности
└── docs/                   # Документация
```

**На сервере (~/clawd/):**
```
├── SOUL.md                 # Личность бота (он сам пишет)
├── USER.md                 # Заметки о тебе (он сам пишет)
├── skills/                 # Навыки бота
├── memory/                 # Долгосрочная память
└── custom/                 # Его заметки и файлы
```

---

## Повседневное использование

### Безопасный деплой (рекомендуется)
```bash
./scripts/safe-push.sh      # Сначала сохранит работу бота, потом отправит твои изменения
```

Этот скрипт:
1. Коммитит все изменения бота на сервере
2. Пушит их в GitHub
3. Скачивает работу бота к тебе
4. Показывает diff твоих изменений
5. Спрашивает подтверждение
6. Только потом отправляет

### Получить работу бота (только pull)
```bash
./scripts/sync.sh pull      # Скачать SOUL.md, skills/, memory/
```

### Логи
```bash
ssh moltbot@YOUR_SERVER_IP "journalctl --user -u moltbot -f"
```

### Рестарт
```bash
ssh moltbot@YOUR_SERVER_IP "systemctl --user restart moltbot"
```

---

## Troubleshooting

### Бот не отвечает в Telegram
```bash
# Проверь статус
ssh server "systemctl --user status moltbot"

# Проверь логи
ssh server "journalctl --user -u moltbot -n 50"
```

### Config invalid
```bash
# Сделай бэкап перед правкой!
ssh server "cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak"

# Проверь docs перед изменением полей!
# https://docs.openclaw.ai
```

### Бот в crash loop
```bash
# Смотри логи — там будет причина
ssh server "journalctl --user -u moltbot -n 100"

# Обычно: неверное поле в конфиге
# Решение: откатиться на бэкап или убрать проблемное поле
```

---

## Безопасность: защита от утечек секретов

### Установка pre-commit hooks

После настройки `.env` выполни:

```bash
./scripts/install-hooks.sh
```

Это установит pre-commit hooks которые блокируют коммиты с секретами:
- В локальном репо
- На сервере (my-bot-memory)

### Что детектируется

| Паттерн | Сервис |
|---------|--------|
| `sk-ant-...` | Anthropic |
| `sk-proj-...` | OpenAI |
| `gsk_...` | Groq |
| `AIzaSy...` | Google/Gemini |
| UUID | Exa и другие |
| `123456:ABC...` | Telegram |

### Правила

1. **Секреты только в `~/.openclaw/openclaw.json`** — никогда в код
2. **В скриптах используй `$ENV_VAR`** — проверяй что переменная задана
3. **Pre-commit hook блокирует** — если видишь ошибку, исправь перед коммитом

### Ручная проверка

```bash
./scripts/check-secrets.sh              # проверить staged файлы
./scripts/check-secrets.sh file.sh      # проверить конкретный файл
```

### Подробнее

См. [docs/security/INDEX.md](docs/security/INDEX.md) — полный процесс и incident response.

---

## Полезные ссылки

- **Moltbot docs:** https://docs.openclaw.ai
- **Конфигурация:** https://docs.openclaw.ai/gateway/configuration
- **Skills:** https://docs.openclaw.ai/tools/skills

---

## Финальный шаг: настрой свой CLAUDE.md

Файл `CLAUDE.md` содержит инструкции для Claude Code. Нужно настроить его под свой сервер:

```bash
# Скопируй шаблон
cp CLAUDE.md.template CLAUDE.md

# Замени плейсхолдеры на реальные данные:
# __SERVER_IP__ → твой IP сервера
# __SERVER_USER__ → твой пользователь (обычно moltbot)
```

После этого Claude Code будет знать:
- Как деплоить твой бот
- Критические ошибки которых избегать
- Структуру твоего проекта

---

## Готово!

Теперь у тебя есть:
- ✅ Работающий Telegram бот с AI
- ✅ Persistent memory (Gemini embeddings — бесплатно!)
- ✅ SessionMemory — индексирует ВСЮ переписку автоматически
- ✅ Hybrid search — 70% семантика + 30% ключевые слова
- ✅ Автобэкап на GitHub
- ✅ Safe sync между локальным и сервером

Напиши боту — он ответит! Со временем он будет помнить контекст, учиться твоим предпочтениям, и развивать свои skills.
