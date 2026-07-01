#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

if ! command -v clang-format >/dev/null 2>&1; then
    echo "[clang-format] clang-format not found in PATH" >&2
    exit 127
fi

mode="format"
if [[ "${1:-}" == "--check" ]]; then
    mode="check"
fi

# Format tracked Objective-C source/header files in this repository.
files=()
while IFS= read -r -d '' file; do
    files+=("${file}")
done < <(git ls-files -z -- '*.h' '*.m' '*.mm')

if [[ "${#files[@]}" -eq 0 ]]; then
    echo "[clang-format] no matching files"
    exit 0
fi

if [[ "${mode}" == "check" ]]; then
    echo "[clang-format] checking ${#files[@]} files"
    clang-format --dry-run --Werror "${files[@]}"
    echo "[clang-format] all files are formatted"
else
    echo "[clang-format] formatting ${#files[@]} files"
    clang-format -i "${files[@]}"
    echo "[clang-format] done"
fi
