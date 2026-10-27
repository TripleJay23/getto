#!/usr/bin/env bash
set -euo pipefail

fail=0

check_forbidden() {
  local name="$1"
  local roots="$2"
  local pattern="$3"

  local files
  files=$(find $roots -type f -name '*.dart' 2>/dev/null || true)

  [ -z "$files" ] && return 0

  if grep -En "$pattern" $files; then
    echo
    echo "ARCHITECTURE VIOLATION: $name"
    fail=1
  fi
}

check_forbidden \
  "Domain must remain pure Dart" \
  "lib/core/domain lib/features/*/domain" \
  "package:(flutter|flutter_riverpod|riverpod|drift|sqlite3|go_router)/"

check_forbidden \
  "Application must not depend on Flutter/persistence/navigation frameworks" \
  "lib/features/*/application" \
  "package:(flutter|flutter_riverpod|riverpod|drift|sqlite3|go_router)/"

check_forbidden \
  "Data must not depend on UI/navigation/state frameworks" \
  "lib/features/*/data" \
  "package:(flutter|flutter_riverpod|riverpod|go_router)/"

check_forbidden \
  "Presentation must not depend directly on database libraries" \
  "lib/features/*/presentation" \
  "package:(drift|sqlite3)/"

check_forbidden \
  "Design system must not own feature/database business logic" \
  "lib/design_system" \
  "package:getto/(features|core/database)/"

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "Architecture dependency boundary check passed."
