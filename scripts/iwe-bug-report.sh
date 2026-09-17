#!/bin/bash
# iwe-bug-report.sh — обёртка для скилла /iwe-bug-report
# Использование: ./iwe-bug-report.sh "описание проблемы"

set -e

PROBLEM="$*"

if [ -z "$PROBLEM" ]; then
  echo "Использование: $0 \"описание проблемы\""
  exit 1
fi

# --- Гейт апстрима (решение пилота 2026-09-17) ---
# Отправка issue вендору по умолчанию запрещена: установка давно не обновлялась,
# ушла от исходной версии, шаблон рассчитан на macOS, а здесь свой код IWE на Windows.
# Разрешение — только явная переменная окружения IWE_ALLOW_UPSTREAM_ISSUE=1,
# которую выставляет пилот (или агент по прямому указанию пилота в текущем диалоге).
if [ "${IWE_ALLOW_UPSTREAM_ISSUE:-}" != "1" ]; then
  cat >&2 <<'GATE'
Апстрим-репорт отключён (решение пилота 2026-09-17).
Issue вендору НЕ создан. Покажи отчёт пилоту и зафиксируй дефект локально
(docs/LOCAL-CUSTOMIZATIONS.md в репозитории управления, §6) или в текущем РП.
Одобрение даёт пилот: переменная IWE_ALLOW_UPSTREAM_ISSUE=1 должна стоять в
окружении его сессии, после чего скрипт спросит интерактивное подтверждение
в терминале. Инлайновая запись переменной в тексте команды заблокирована
guard-хуком upstream-issue-gate.sh как самоподтверждение.
GATE
  exit 3
fi

# Второй контур: одобрение подтверждает человек в своём терминале. В сессии
# агента TTY нет (stdin не терминал), поэтому отправить issue из агента нельзя
# даже при выставленной переменной — это и есть гейт.
if [ ! -t 0 ] || [ ! -r /dev/tty ]; then
  cat >&2 <<'NOTTY'
Отправка требует интерактивного подтверждения в терминале пилота.
В сессии агента TTY нет — issue НЕ отправлен.
Запусти скрипт сам в своём терминале (переменная IWE_ALLOW_UPSTREAM_ISSUE=1).
NOTTY
  exit 3
fi
printf 'Отправить issue в репозиторий вендора %s? [y/N]: ' "TserenTserenov/FMT-exocortex-template" > /dev/tty
_answer=""
if ! IFS= read -r _answer < /dev/tty; then
  echo "Не удалось прочитать подтверждение — отменено, issue не создан." >&2
  exit 3
fi
case "$_answer" in
  y|Y|yes|YES|да|Да|ДА) ;;
  *) echo "Отменено пилотом — issue не создан." >&2; exit 3 ;;
esac

# Путь к FMT-шаблону
FMT_PATH="${IWE_FMT_PATH:-$HOME/IWE/FMT-exocortex-template}"
if [ ! -d "$FMT_PATH" ]; then
  echo "Ошибка: FMT не найден. Установи IWE_FMT_PATH или проверь ~/IWE/FMT-exocortex-template"
  exit 1
fi

# Проверка gh CLI
if ! command -v gh &> /dev/null; then
  echo "Ошибка: gh CLI не установлен. Установи: brew install gh && gh auth login"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo "Ошибка: gh не авторизован. Выполни: gh auth login"
  exit 1
fi

# Получить версию IWE
IWE_VERSION=$(cd "$FMT_PATH" && git log -1 --format="%h %ad" --date=short 2>/dev/null || echo "неизвестно")

# Категории (простое определение по ключевым словам)
CATEGORY="enhancement"  # дефолт
if echo "$PROBLEM" | grep -iq "ошибка\|крашится\|упало\|не работает"; then
  CATEGORY="bug"
elif echo "$PROBLEM" | grep -iq "документация\|описание\|readme"; then
  CATEGORY="docs"
fi

# Заголовок (первые 80 символов с учётом префикса категории)
PREFIX="[$CATEGORY] "
MAX_LEN=$((80 - ${#PREFIX}))
TITLE="${PREFIX}${PROBLEM:0:$MAX_LEN}"

# Дата
DATE=$(date +%Y-%m-%d)

# Создать issue
echo "📝 Создаю issue в FMT-exocortex-template..."

BODY=$(cat <<BODY
## Что произошло

$PROBLEM

## Контекст

- Дата: $DATE
- IWE commit: $IWE_VERSION
BODY
)

if OUTPUT=$(gh issue create \
  --repo TserenTserenov/FMT-exocortex-template \
  --title "$TITLE" \
  --label "$CATEGORY" \
  --body "$BODY" 2>&1); then
  echo "✅ Issue создан:"
  echo "$OUTPUT"
else
  echo "❌ Ошибка при создании issue:"
  echo "$OUTPUT"
  exit 1
fi
