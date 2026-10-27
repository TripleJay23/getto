#!/usr/bin/env bash
set -euo pipefail

./tool/check_architecture.sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
git diff --check
