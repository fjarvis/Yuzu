#!/usr/bin/env bash
# Erlang gateway verification sequence.
#
# Runs the canonical check for the Yuzu gateway:
#   rebar3 compile -> rebar3 eunit -> rebar3 dialyzer
# then scans for stray .beam / erl_crash.dump artifacts that must not
# be committed.
#
# Exits non-zero on the first failure.
#
# Usage:
#   bash .claude/skills/erlang-dialyzer-check/scripts/verify.sh
#   bash .claude/skills/erlang-dialyzer-check/scripts/verify.sh --no-dialyzer
#   bash .claude/skills/erlang-dialyzer-check/scripts/verify.sh --ct some_SUITE

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
GATEWAY_DIR="$REPO_ROOT/gateway"

if [[ ! -d "$GATEWAY_DIR" ]]; then
  echo "!! $GATEWAY_DIR does not exist" >&2
  exit 1
fi

RUN_DIALYZER=1
CT_SUITE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-dialyzer) RUN_DIALYZER=0; shift ;;
    --ct)
      shift
      if [[ $# -eq 0 ]]; then
        echo "!! --ct requires a suite name" >&2
        exit 2
      fi
      CT_SUITE="$1"
      shift
      ;;
    -h|--help)
      sed -n '2,14p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }

cd "$GATEWAY_DIR"
step "gateway: $GATEWAY_DIR"

step "rebar3 compile"
rebar3 compile

step "rebar3 eunit"
rebar3 eunit

if [[ $RUN_DIALYZER -eq 1 ]]; then
  step "rebar3 dialyzer"
  rebar3 dialyzer
else
  step "skipping dialyzer (--no-dialyzer)"
fi

if [[ -n "$CT_SUITE" ]]; then
  step "rebar3 ct --dir apps/yuzu_gw/test --suite $CT_SUITE"
  rebar3 ct --dir apps/yuzu_gw/test --suite "$CT_SUITE"
fi

step "scanning for stray .beam and crash dumps outside _build/"
STRAY=0
while IFS= read -r artifact; do
  echo "  stray: $artifact"
  STRAY=1
done < <(
  find "$GATEWAY_DIR" \
    -path "$GATEWAY_DIR/_build" -prune -o \
    \( -name '*.beam' -o -name 'erl_crash.dump' \) -print 2>/dev/null
)

if [[ $STRAY -eq 1 ]]; then
  echo
  echo "!! Stray build/runtime artifacts found (see pitfall #5)." >&2
  echo "!! Delete them or add to .gitignore before committing." >&2
  exit 1
fi

printf '\n==> Erlang gateway check PASSED\n'
