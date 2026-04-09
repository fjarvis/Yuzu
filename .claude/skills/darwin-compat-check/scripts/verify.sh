#!/usr/bin/env bash
# Darwin compatibility verification sequence.
#
# Runs the canonical check for Yuzu on macOS:
#   fetch -> status -> pull (if tracking) -> meson reconfigure (if needed)
#   -> meson compile -> full test suite
#
# Exits non-zero on the first failure.
#
# Usage:
#   bash .claude/skills/darwin-compat-check/scripts/verify.sh          # full run
#   bash .claude/skills/darwin-compat-check/scripts/verify.sh --no-pull  # skip fast-forward

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

PULL=1
for arg in "$@"; do
  case "$arg" in
    --no-pull) PULL=0 ;;
    -h|--help)
      sed -n '2,14p' "${BASH_SOURCE[0]}"
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

step "git fetch origin"
git fetch origin

step "git status"
git status --short --branch

if [[ $PULL -eq 1 ]]; then
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if git show-ref --verify --quiet "refs/remotes/origin/$CURRENT_BRANCH"; then
    step "git pull --ff-only origin $CURRENT_BRANCH"
    git pull --ff-only origin "$CURRENT_BRANCH"
  else
    step "no upstream for $CURRENT_BRANCH — skipping pull"
  fi
else
  step "skipping pull (--no-pull)"
fi

step "recent commits"
git log --oneline -5

if [[ ! -d builddir ]]; then
  echo
  echo "!! builddir/ does not exist. Run ./scripts/setup.sh first." >&2
  exit 1
fi

# Reconfigure only if meson.build changed in the last 10 commits.
if git diff HEAD~10..HEAD --name-only 2>/dev/null | grep -qE '(^|/)meson\.build$'; then
  step "meson.build changed recently — reconfiguring builddir"
  meson setup builddir --reconfigure
fi

step "meson compile -C builddir"
meson compile -C builddir

step "bash scripts/run-tests.sh all"
bash scripts/run-tests.sh all

printf '\n==> Darwin compat check PASSED\n'
