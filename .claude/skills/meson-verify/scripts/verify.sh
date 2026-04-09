#!/usr/bin/env bash
# Meson build verification with source-file drift detection.
#
# Runs:
#   1. Drift scan — every .cpp/.hpp under agents/, server/, sdk/, tests/
#      must be referenced by at least one meson.build.
#   2. Reconfigure — if any meson.build changed in the last 10 commits.
#   3. Compile — meson compile -C builddir.
#
# Exits non-zero on the first failure.
#
# Usage:
#   bash .claude/skills/meson-verify/scripts/verify.sh
#   bash .claude/skills/meson-verify/scripts/verify.sh --no-drift
#   bash .claude/skills/meson-verify/scripts/verify.sh --no-reconfigure

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

RUN_DRIFT=1
RUN_RECONFIGURE=1

for arg in "$@"; do
  case "$arg" in
    --no-drift)       RUN_DRIFT=0 ;;
    --no-reconfigure) RUN_RECONFIGURE=0 ;;
    -h|--help)
      sed -n '2,13p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }

step "repo: $REPO_ROOT"

if [[ ! -d builddir ]]; then
  echo "!! builddir/ does not exist. Run ./scripts/setup.sh first." >&2
  exit 1
fi

# ---------------------------------------------------------------------
# Drift scan: every .cpp/.hpp on disk must be referenced by a meson.build
# ---------------------------------------------------------------------
if [[ $RUN_DRIFT -eq 1 ]]; then
  step "drift scan — checking .cpp/.hpp files are referenced by meson.build"

  SCAN_DIRS=(agents server sdk tests)
  EXISTING_DIRS=()
  for d in "${SCAN_DIRS[@]}"; do
    [[ -d "$d" ]] && EXISTING_DIRS+=("$d")
  done

  if [[ ${#EXISTING_DIRS[@]} -eq 0 ]]; then
    echo "!! no scan directories found" >&2
    exit 1
  fi

  # Collect all meson.build contents once.
  MESON_BLOB="$(mktemp)"
  trap 'rm -f "$MESON_BLOB"' EXIT
  find "${EXISTING_DIRS[@]}" -name 'meson.build' -print0 \
    | xargs -0 cat > "$MESON_BLOB" 2>/dev/null || true

  DRIFT=0
  while IFS= read -r src; do
    # Skip generated proto output directories.
    case "$src" in
      */build/*|*/builddir/*|*/_build/*|*/subprojects/*) continue ;;
    esac
    filename="$(basename "$src")"
    if ! grep -qF "$filename" "$MESON_BLOB"; then
      echo "  drift: $src not referenced by any meson.build"
      DRIFT=1
    fi
  done < <(
    find "${EXISTING_DIRS[@]}" \
      \( -name '*.cpp' -o -name '*.hpp' -o -name '*.cc' -o -name '*.h' \) \
      -type f
  )

  if [[ $DRIFT -eq 1 ]]; then
    echo
    echo "!! Source file drift detected (pitfall #1)." >&2
    echo "!! Add the missing files to the affected meson.build." >&2
    exit 1
  fi

  echo "  no drift — all source files referenced"
else
  step "skipping drift scan (--no-drift)"
fi

# ---------------------------------------------------------------------
# Reconfigure if any meson.build changed recently.
# ---------------------------------------------------------------------
if [[ $RUN_RECONFIGURE -eq 1 ]]; then
  if git diff HEAD~10..HEAD --name-only 2>/dev/null \
       | grep -qE '(^|/)meson\.build$'; then
    step "meson.build changed recently — reconfiguring builddir"
    meson setup builddir --reconfigure
  else
    step "no recent meson.build changes — skipping reconfigure"
  fi
else
  step "skipping reconfigure (--no-reconfigure)"
fi

# ---------------------------------------------------------------------
# Compile.
# ---------------------------------------------------------------------
step "meson compile -C builddir"
meson compile -C builddir

printf '\n==> Meson verify PASSED\n'
