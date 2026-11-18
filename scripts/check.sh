#!/usr/bin/env bash
# ZaphShell validation script: lints all QML files and checks bash script syntax.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Checking script syntax..."
for sh_file in "$ROOT_DIR"/install.sh "$ROOT_DIR"/uninstall.sh "$ROOT_DIR"/scripts/*.sh "$ROOT_DIR"/config/quickshell/scripts/*.sh; do
    [ -f "$sh_file" ] || continue
    first_line="$(head -n 1 "$sh_file")"
    if [[ "$first_line" == *"python"* ]]; then
        PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile "$sh_file"
    else
        bash -n "$sh_file"
    fi
done
echo "✓ All scripts passed syntax check."

if command -v qmllint >/dev/null 2>&1; then
    echo "==> Running qmllint on QML files..."
    mapfile -t qml_files < <(find "$ROOT_DIR/config/quickshell" -name '*.qml' | sort)
    qmllint "${qml_files[@]}"
    echo "✓ All ${#qml_files[@]} QML files passed qmllint."
else
    echo "⚠ qmllint not found, skipping QML lint."
fi
