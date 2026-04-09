---
name: erlang-dialyzer-check
description: Verify Yuzu gateway builds cleanly and passes dialyzer. Use after any .erl change, rebar.config edit, yuzu_gw.app.src modification, Erlang proto regeneration, or before committing gateway code. Runs compile + eunit + dialyzer and flags standing gateway pitfalls.
allowed-tools:
  - Bash(bash .claude/skills/erlang-dialyzer-check/scripts/verify.sh*)
  - Bash(cd gateway && rebar3 *)
  - Bash(rebar3 *)
  - Bash(find gateway *)
---

# Erlang Gateway Dialyzer & Test Check

Use this skill when verifying that Erlang gateway changes compile cleanly,
pass unit tests, and survive dialyzer's type analysis. **Compilation is
not enough** — the project uses `warnings_as_errors` for compile, but
dialyzer runs separately and is the mechanism that actually catches type
violations, dead code, and missing transitive-dependency declarations.

## When to use

- You edited any file under `gateway/apps/` or `gateway/apps/*/src/`.
- You changed `rebar.config`, `yuzu_gw.app.src`, or any other `.app.src`.
- You called a function from a transitive dependency for the first time
  (see pitfall #1 — dialyzer will reject it).
- You regenerated protobuf stubs for the gateway.
- You are about to commit Erlang changes.
- You suspect a Dialyzer warning is a false positive (check `pitfalls.md`
  before adding a `-dialyzer` attribute to suppress it).

## Quick verification

```bash
bash .claude/skills/erlang-dialyzer-check/scripts/verify.sh
```

Runs, in order: `rebar3 compile` → `rebar3 eunit` → `rebar3 dialyzer`,
then scans the gateway tree for stray `.beam` files and `erl_crash.dump`
artifacts that must not be committed. Exits non-zero on the first failure.

Pass `--no-dialyzer` to skip dialyzer when iterating on eunit tests (but
never commit without a clean dialyzer run). Pass `--ct SUITE` to also run
Common Test against a specific suite — requires `--dir apps/yuzu_gw/test`
internally, see pitfall #7.

## Manual sequence

```bash
cd gateway
rebar3 compile                                  # warnings_as_errors
rebar3 eunit                                    # 148 tests
rebar3 dialyzer                                 # must be warning-free
rebar3 ct --dir apps/yuzu_gw/test --suite foo   # Common Test (optional)
```

## Diagnosing failures

Before investigating a dialyzer warning, read `pitfalls.md` — six recurring
failure modes cover almost every warning we hit in practice:

1. `ctx` (or any transitive dep) not listed in `applications`.
2. `-spec` contract violated in a catch/fallback path.
3. Catchall clause on a structurally-unreachable state (circuit breaker).
4. Benign `gpb` plugin warning being treated as an error.
5. Stray `.beam` / `erl_crash.dump` files in the gateway root.
6. Shutdown flush using `queue_heartbeat/1` with a sentinel atom instead
   of `flush_sync/0`.

If the warning doesn't match any of these, it's a new category. Add it to
`pitfalls.md` as part of the fix.

## Reporting back

After fixing, hand the `gateway-erlang` or `erlang-dev` subagent a short
report: which pitfall matched (or "new category"), the commit SHA of the
fix, and — if it was a new category — a one-paragraph description for
`pitfalls.md`.
