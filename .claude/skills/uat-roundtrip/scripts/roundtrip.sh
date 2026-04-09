#!/usr/bin/env bash
# UAT stack round-trip verification.
#
# Wraps scripts/linux-start-UAT.sh with the canonical pre-flight and
# post-flight sequence:
#   stop (idempotent) -> wipe /tmp/yuzu-uat -> start (runs 6 tests)
#   -> status -> optional stop
#
# The wipe works around the known stale-DB session auth bug (pitfall #1).
# Exits non-zero on the first failure.
#
# Usage:
#   bash .claude/skills/uat-roundtrip/scripts/roundtrip.sh
#   bash .claude/skills/uat-roundtrip/scripts/roundtrip.sh --keep-running
#   bash .claude/skills/uat-roundtrip/scripts/roundtrip.sh --no-wipe

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$REPO_ROOT"

KEEP_RUNNING=0
WIPE=1

for arg in "$@"; do
  case "$arg" in
    --keep-running) KEEP_RUNNING=1 ;;
    --no-wipe)      WIPE=0 ;;
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

UAT_SCRIPT="scripts/linux-start-UAT.sh"
if [[ ! -x "$UAT_SCRIPT" && ! -f "$UAT_SCRIPT" ]]; then
  echo "!! $UAT_SCRIPT not found in $REPO_ROOT" >&2
  exit 1
fi

step() { printf '\n==> %s\n' "$*"; }

PORTS=(8080 50051 50052 50055 50061 50063 8081 9568)

check_ports_free() {
  local busy=0
  for p in "${PORTS[@]}"; do
    if ss -tln "sport = :$p" 2>/dev/null | grep -q LISTEN; then
      echo "  port $p is already bound" >&2
      busy=1
    fi
  done
  return $busy
}

step "preflight: stop any prior UAT stack"
bash "$UAT_SCRIPT" stop || true

if [[ $WIPE -eq 1 ]]; then
  step "wiping /tmp/yuzu-uat (stale-DB workaround — pitfall #1)"
  rm -rf /tmp/yuzu-uat
else
  step "skipping /tmp/yuzu-uat wipe (--no-wipe)"
fi

step "preflight: verifying UAT ports are free"
if ! check_ports_free; then
  echo "!! One or more UAT ports are still bound. See pitfall #3." >&2
  echo "!! Run:  ss -tlnp 'sport = :8080 or sport = :50061 or sport = :50063'" >&2
  exit 1
fi

step "starting UAT stack (scripts/linux-start-UAT.sh — runs 6 round-trip tests)"
bash "$UAT_SCRIPT"

step "status"
bash "$UAT_SCRIPT" status || true

if [[ $KEEP_RUNNING -eq 1 ]]; then
  printf '\n==> UAT stack left running (--keep-running)\n'
  printf '==> tear down later with:  bash %s stop\n' "$UAT_SCRIPT"
else
  step "tearing down UAT stack"
  bash "$UAT_SCRIPT" stop
fi

printf '\n==> UAT round-trip PASSED\n'
