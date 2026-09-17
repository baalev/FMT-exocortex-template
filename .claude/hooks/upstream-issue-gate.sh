#!/usr/bin/env bash
# PreToolUse:Bash guard — не даёт создать issue/PR, написать комментарий или
# изменить issue в репозитории вендора (TserenTserenov/FMT-exocortex-template)
# без явного одобрения пилота. Решение пилота 2026-09-17: установка давно не
# обновлялась, живёт на Windows со своим кодом IWE, апстрим-репорты создают шум.
# Exit 2 = block.
set -euo pipefail

INPUT=$(cat)

# Fail-closed: вход не разобран (нет jq / битый JSON) — блокируем, а не пропускаем:
# предохранитель не должен молча превращаться в пустышку.
if ! printf '%s' "$INPUT" | jq -e . >/dev/null 2>&1; then
  echo "BLOCKED: upstream-issue-gate не смог разобрать вход хука (нет jq или битый JSON) — fail-closed." >&2
  exit 2
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // .tool_input.cwd // empty')

block() {
  echo "BLOCKED: $1" >&2
  exit 2
}

# Одобрение — только из окружения сессии пилота. Инлайновая переменная в тексте
# команды одобрением НЕ считается (иначе агент выдаёт разрешение сам себе) и
# блокируется как попытка самоподтверждения.
if printf '%s' "$CMD" | grep -qE '(^|[;&|[:space:]])(export[[:space:]]+|env[[:space:]]+)?IWE_ALLOW_UPSTREAM_ISSUE='; then
  block "переменную одобрения IWE_ALLOW_UPSTREAM_ISSUE нельзя выставлять в тексте команды — одобрение даёт пилот в своём окружении."
fi
[ "${IWE_ALLOW_UPSTREAM_ISSUE:-}" = "1" ] && exit 0

# Переносы строк и CR схлопываем, чтобы многострочная команда не проскакивала.
CMD_NORM=$(printf '%s' "$CMD" | tr '\r\n' '  ')

has_gh() {
  printf '%s' "$1" | grep -qE '(^|[;&|()[:space:]])gh[[:space:]]' && return 0
  return 1
}
has_issue_pr_write() {
  printf '%s' "$1" | grep -qiE '(^|[[:space:]])(issue|pr)[[:space:]]+(create|comment|close|reopen|edit|transfer|delete|lock|unlock|pin)([[:space:]]|$)' && return 0
  return 1
}
has_api_write() {
  printf '%s' "$1" | grep -qiE '(^|[[:space:]])api([[:space:]]|$)' \
    && printf '%s' "$1" | grep -qiE '(--method|-X)[= ]*(POST|PATCH|PUT|DELETE)|(-f|-F|--field|--raw-field|--input)([= ]|$)' && return 0
  return 1
}
has_alias() {
  printf '%s' "$1" | grep -qiE '(^|[[:space:]])alias([[:space:]]|$)' && return 0
  return 1
}
is_gh_write() {
  has_gh "$1" || return 1
  has_issue_pr_write "$1" && return 0
  has_api_write "$1" && return 0
  has_alias "$1" && return 0
  return 1
}

# Явно указанный получатель: --repo R, --repo=R, -R R, URL репозитория.
target_repo() {
  printf '%s' "$1" \
    | grep -oiE '(--repo[= ]|-R[ =])[A-Za-z0-9_.:/-]+/[A-Za-z0-9_.-]+' \
    | tail -n1 | sed -E 's/^(--repo[= ]|-R[ =])//' | sed -E 's#^[a-z]+://[^/]+/##' || true
}

# Вендор, указанный как путь API или URL (а не просто упомянутый в тексте).
VENDOR_PATH_RE='(/repos/|github\.com/)[^[:space:]]*TserenTserenov/FMT-exocortex-template'

is_gh_write "$CMD_NORM" || exit 0

TARGET=$(target_repo "$CMD_NORM")
TARGET_LC=$(printf '%s' "$TARGET" | tr 'A-Z' 'a-z')

if [ -n "$TARGET" ]; then
  case "$TARGET_LC" in
    tserentserenov/fmt-exocortex-template|*/fmt-exocortex-template)
      block "запись в issue/PR репозитория вендора ($TARGET) отключена решением пилота (2026-09-17). Нужно явное одобрение пилота."
      ;;
  esac
  exit 0
fi

# Получатель не указан явно: вендорским считаем адрес API/URL вендора или запуск
# из каталога шаблона вендора (там gh возьмёт origin = вендор).
if printf '%s' "$CMD_NORM" | grep -qiE "$VENDOR_PATH_RE"; then
  block "запись в issue/PR вендора отключена решением пилота (2026-09-17). Нужно явное одобрение пилота."
fi
case "$CWD" in
  *FMT-exocortex-template*)
    block "запись в issue/PR из каталога шаблона вендора (origin = вендор) отключена решением пилота (2026-09-17). Укажи явный --repo, если цель — свой репозиторий."
    ;;
esac

exit 0
