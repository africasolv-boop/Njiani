#!/usr/bin/env bash
#
# Runs every check across the whole workspace: lint, then tests for each
# package that has any. `flutter test` cannot run from the workspace root
# (the root holds no test/ directory), so this walks the members.
#
#   ./tool/check.sh
#
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter analyze (whole workspace)"
flutter analyze

failed=0
for pkg in packages/njiani_core apps/njiani_rider apps/njiani_driver; do
  if [ -d "$pkg/test" ]; then
    echo ""
    echo "==> flutter test $pkg"
    (cd "$pkg" && flutter test) || failed=1
  fi
done

echo ""
if [ "$failed" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some tests failed." >&2
fi
exit "$failed"
