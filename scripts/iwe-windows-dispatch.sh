#!/bin/bash
# iwe-windows-dispatch.sh — точка входа для Task Scheduler (Windows/Git Bash).
# Центральный планировщик IWE: scheduler.sh dispatch (каждый час).
set -uo pipefail

source /q/IWE/scripts/iwe-windows-scheduler-env.sh

LOG_DIR="$HOME/logs/synchronizer"
mkdir -p "$LOG_DIR"

LOG="$LOG_DIR/task-scheduler-$(date +%Y-%m-%d).log"
echo "=== dispatch $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG"

exec /q/IWE/.iwe-runtime/roles/synchronizer/scripts/scheduler.sh dispatch >> "$LOG" 2>&1
