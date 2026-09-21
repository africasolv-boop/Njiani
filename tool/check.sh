#!/usr/bin/env bash
#
# Runs every check across the whole workspace: stale-file guard, lint, then
# tests for each package that has any. `flutter test` cannot run from the
# workspace root (the root holds no test/ directory), so this walks the members.
#
#   ./tool/check.sh          report problems
#   ./tool/check.sh --fix    delete stale files, then run the checks
#
set -uo pipefail
cd "$(dirname "$0")/.."

FIX=0
[ "${1:-}" = "--fix" ] && FIX=1

# --------------------------------------------------------------------------
# Stale template files.
#
# `flutter create` generates files we deliberately removed: a counter-app
# widget_test.dart, per-package analysis_options.yaml that would silently
# override the workspace lint config, and template READMEs. They were never
# committed, so `git pull` cannot remove them -- they linger in a working tree
# that ran `flutter create` and break `flutter analyze` with errors that do not
# exist in the repo.
# --------------------------------------------------------------------------
STALE_PATHS=(
  apps/njiani_rider/test/widget_test.dart
  apps/njiani_driver/test/widget_test.dart
  apps/njiani_rider/analysis_options.yaml
  apps/njiani_driver/analysis_options.yaml
  packages/njiani_core/analysis_options.yaml
  apps/njiani_rider/README.md
  apps/njiani_driver/README.md
  packages/njiani_core/CHANGELOG.md
  packages/njiani_core/LICENSE
  apps/njiani_rider/pubspec.lock
  apps/njiani_driver/pubspec.lock
  packages/njiani_core/pubspec.lock
)

echo "==> stale template files"
found=()
for path in "${STALE_PATHS[@]}"; do
  [ -e "$path" ] && found+=("$path")
done

if [ "${#found[@]}" -gt 0 ]; then
  if [ "$FIX" -eq 1 ]; then
    for path in "${found[@]}"; do
      rm -f "$path"
      echo "    removed $path"
    done
  else
    echo ""
    echo "    Found ${#found[@]} stale file(s) that are not in the repo." >&2
    echo "    They are left over from 'flutter create' and will break the build" >&2
    echo "    with errors that do not exist in git. Remove them:" >&2
    echo "" >&2
    printf '      rm -f %s\n' "${found[@]}" >&2
    echo "" >&2
    echo "    Or re-run:  ./tool/check.sh --fix" >&2
    exit 1
  fi
else
  echo "    none"
fi

# --------------------------------------------------------------------------
# Localisations.
#
# The generated strings are committed so a fresh clone analyses and tests
# without a codegen step. That only works if they stay in step with the .arb
# files, so regenerate and fail if anything moved.
# --------------------------------------------------------------------------
echo ""
echo "==> localisations"
(cd packages/njiani_core && flutter gen-l10n >/dev/null 2>&1) || {
  echo "    gen-l10n failed" >&2
  exit 1
}
if ! git diff --quiet -- packages/njiani_core/lib/src/l10n/generated 2>/dev/null; then
  if [ "$FIX" -eq 1 ]; then
    echo "    regenerated (commit the result)"
  else
    echo "" >&2
    echo "    Generated strings are out of date with the .arb files." >&2
    echo "    They have just been regenerated -- review and commit:" >&2
    echo "" >&2
    git --no-pager diff --stat -- packages/njiani_core/lib/src/l10n/generated >&2
    echo "" >&2
    exit 1
  fi
else
  echo "    up to date"
fi

echo ""
echo "==> flutter analyze (whole workspace)"
flutter analyze || exit 1

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
