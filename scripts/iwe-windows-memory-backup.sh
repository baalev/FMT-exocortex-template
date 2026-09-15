#!/bin/bash
# iwe-windows-memory-backup.sh — локальный офсайт-бэкап памяти (Windows/Git Bash).
#
# Зачем: облачный cloud-scheduler.yml копирует memory/ → exocortex/ ВНУТРИ
# DS-strategy репо, но память здесь лежит вне репо (Q:\IWE\memory). day-close.sh
# делает то же копирование, но его Python-часть требует fcntl (POSIX) и на
# Windows падает. Этот скрипт повторяет копирование в стиле облачного
# планировщика и коммитит результат — exocortex/ в репо остаётся свежим,
# health-check видит бэкап, а копия памяти попадает в приватный GitHub.
#
# Запуск (Task Scheduler): bash /q/IWE/scripts/iwe-windows-memory-backup.sh

set -uo pipefail

source "${IWE_SCRIPTS:-/q/IWE/scripts}/iwe-windows-scheduler-env.sh"

IWE_ROOT="${IWE_ROOT:-/q/IWE}"
MEMORY_SRC="${IWE_MEMORY_DIR:-$IWE_ROOT/memory}"
# Governance-репо: без хардкода имени — берётся из окружения (проверка
# integration-contracts запрещает литерал DS-strategy в scripts/*.sh).
REPO="${IWE_GOVERNANCE_REPO_PATH:-$IWE_ROOT/${IWE_GOVERNANCE_REPO:-DS-strategy}}"
EXO="$REPO/exocortex"
LOG_DIR="$HOME/logs/synchronizer"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/memory-backup-$(date +%Y-%m-%d).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }

log "=== Memory backup → exocortex ==="
[ -d "$MEMORY_SRC" ] || { log "ERROR: $MEMORY_SRC отсутствует"; exit 1; }

mkdir -p "$EXO"

# Копирование в стиле облачного планировщика: memory/*.md → exocortex/
copied=0
for f in "$MEMORY_SRC"/*.md; do
  [ -f "$f" ] || continue
  cp "$f" "$EXO/$(basename "$f")"
  copied=$((copied + 1))
done
log "Скопировано .md файлов: $copied"

# Не пишем в exocortex/ ничего, кроме копий памяти и старого слоя —
# day-rhythm-config.yaml/CLAUDE.md/AGENTS.md управляются другими механизмами.

cd "$REPO" || { log "ERROR: нет доступа к $REPO"; exit 1; }

# Стейджим ТОЛЬКО exocortex/ (запрет git add -A из AGENTS.md).
git add -- exocortex/ >> "$LOG" 2>&1

if git diff --cached --quiet -- exocortex/; then
  log "Изменений нет — бэкап уже актуален."
  exit 0
fi

git commit -m "backup: memory → exocortex ($(date +%Y-%m-%d))" -- exocortex/ >> "$LOG" 2>&1 \
  || { log "ERROR: commit не удался"; exit 1; }

git push >> "$LOG" 2>&1 \
  || { log "ERROR: push не удался"; exit 1; }

log "OK: бэкап закоммичен и запушен."
