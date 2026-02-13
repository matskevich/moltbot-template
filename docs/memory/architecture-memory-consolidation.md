# Memory Consolidation Architecture

## Проблема

Moltbot имеет "амнезию по дизайну":
- Compaction = полная потеря контекста
- memoryFlush недостаточен — срабатывает в панике
- .bak файлы не индексируются
- Нет восстановления после compaction

## Как работает память у людей

```
Working Memory (секунды-минуты)
      │
      ▼ encoding (во время работы)
Short-term Memory (минуты-часы)
      │
      ▼ consolidation (сон, отдых)
Long-term Memory (дни-годы)
      │
      ▼ retrieval (по триггеру)
Working Memory (загрузка релевантного)
```

## Как должно работать у Moltbot

### 1. Continuous Encoding (во время работы)

Агент постоянно записывает в персистентные файлы:

| Файл | Что записывается | Когда |
|------|------------------|-------|
| `custom/action-log.md` | Важные действия | После каждого значимого действия |
| `custom/learnings.md` | Новые знания | Когда узнал что-то новое |
| `custom/self-notes.md` | Заметки себе | Незавершённые задачи, контекст |

### 2. Memory Flush (перед compaction)

Улучшенный systemPrompt:

```
Сессия приближается к compaction. Запиши:

1. **Summary диалога** (последние 10-15 обменов) в memory/sessions/YYYY-MM-DD-HH-summary.md
2. **Незавершённые задачи** в custom/self-notes.md
3. **Новые факты о владельце** в custom/learnings.md

Формат summary:
## Session Summary YYYY-MM-DD HH:MM

### Контекст
[Что обсуждалось]

### Ключевые решения
- [Решение 1]
- [Решение 2]

### Незавершённое
- [ ] [Задача 1]

### Факты для памяти
- [Факт 1]
```

### 3. Memory Consolidation (ночной cron)

Cron job `memory-consolidation` (02:00 UTC):

1. Найти все .bak файлы за день
2. Извлечь ключевые факты через LLM
3. Сохранить в `memory/consolidated/YYYY-MM-DD.md`
4. Обновить индексы

### 4. Session Bootstrap (при старте)

При начале новой сессии:

1. `memory_search` по последним self-notes
2. Загрузить актуальный контекст
3. Показать агенту что было вчера

---

## Границы кастомизации Moltbot

### Можем менять (через конфиг)

| Компонент | Параметры | Файл |
|-----------|-----------|------|
| memoryFlush | prompt, systemPrompt, softThresholdTokens | moltbot.json |
| compaction.mode | default / safeguard | moltbot.json |
| Prompts | Личность, правила | AGENTS.md, SOUL.md |
| Skills | Любые кастомные | skills/*.md |
| Memory | Структура файлов | memory/*.md |

### Требует форк (нет API)

| Компонент | Почему нельзя |
|-----------|---------------|
| Post-compaction hook | Нет callback после compaction |
| Индексация .bak | Hardcoded в memory_search |
| Session recovery | Нет механизма |
| Transcript format | Внутренний JSONL |

---

## План реализации

### Фаза 1: Улучшить memoryFlush (1 день)

1. Обновить `compaction.memoryFlush.systemPrompt` с детальными инструкциями
2. Увеличить `softThresholdTokens` для более раннего срабатывания
3. Создать структуру `memory/sessions/`

### Фаза 2: Continuous encoding (2-3 дня)

1. Добавить в AGENTS.md правила постоянной записи
2. Создать шаблоны для action-log, learnings, self-notes
3. Тестировать на реальных диалогах

### Фаза 3: Memory consolidation cron (3-5 дней)

1. Создать skill `memory-consolidation`
2. Настроить cron (02:00 UTC)
3. Создать парсер .bak файлов
4. Тестировать извлечение фактов

### Фаза 4: Session bootstrap (2-3 дня)

1. Добавить в AGENTS.md инструкции для начала сессии
2. Тестировать восстановление контекста
3. Итерировать на основе результатов

---

## Метрики успеха

1. **Continuity score**: % сессий где агент помнит контекст предыдущего дня
2. **Context recovery**: % важных фактов восстановленных после compaction
3. **Action log coverage**: % значимых действий записанных в лог

---

## Связанные документы

- [SECURITY.md](../prompts/SECURITY.md) — правила безопасности
- [architecture-sandboxed-research.md](architecture-sandboxed-research.md) — изоляция исследований
- [night-review skill](../skills/night-review/) — ночной ритуал самоанализа

---

**Версия:** 1.0
**Дата:** 2026-02-02
**Автор:** owner + Claude
