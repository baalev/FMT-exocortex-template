#!/bin/bash
# to-native-path.sh — конвертация пути для НАТИВНОГО интерпретатора.
#
# Зачем: в Git Bash на Windows `python3` — это Windows-Python. Путь вида
# /q/IWE/... (MSYS) он открыть не может: «No such file or directory».
# cygpath -m даёт Q:/IWE/... — такой путь понятен и Python, и git.
# На Linux/macOS cygpath нет, путь возвращается как есть.
#
# Использование:
#   . "$(dirname "$0")/lib/to-native-path.sh"
#   NATIVE=$(to_native_path "$SOME_MSYS_PATH")
#
# Правило: конвертировать нужно пути, попадающие ВНУТРЬ кода Python (open(),
# Path(), cwd=). Пути, передаваемые как аргументы, MSYS конвертирует сам.

to_native_path() {
    local p="$1"
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m -- "$p" 2>/dev/null || printf '%s' "$p"
    else
        printf '%s' "$p"
    fi
}
