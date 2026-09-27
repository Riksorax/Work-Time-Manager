#!/usr/bin/env bash
# PostToolUse-Hook: formatiert eine gerade von Claude bearbeitete Dart-Datei
# automatisch, damit `dart format --set-exit-if-changed` in der CI (#299)
# nie wegen liegen gebliebener Formatierung fehlschlägt.
set -euo pipefail

file_path=$(jq -r '.tool_input.file_path // empty')

[[ -z "$file_path" ]] && exit 0
[[ "$file_path" != *.dart ]] && exit 0
# Generierte Dateien nie anfassen - Codegen liefert bereits kanonisch
# formatierten Code, ein erneuter Lauf würde nur unnötig Zeit kosten.
[[ "$file_path" == *.g.dart || "$file_path" == *.mocks.dart ]] && exit 0
[[ -f "$file_path" ]] || exit 0

dart format "$file_path" >/dev/null 2>&1 || true
