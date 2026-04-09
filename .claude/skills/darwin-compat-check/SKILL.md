---
name: darwin-compat-check
description: Verify macOS/Darwin compatibility. Use after Windows-originated commits land, when .cpp/.hpp/meson.build change, when SQLite stores or path comparison code is touched, when Erlang rebar3 ct or prometheus_httpd startup is modified, or before committing a cross-platform fix.
allowed-tools:
  - Bash(git status)
  - Bash(git fetch *)
  - Bash(git pull *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git rev-parse *)
  - Bash(git show-ref *)
  - Bash(meson setup *)
  - Bash(meson compile *)
  - Bash(bash scripts/run-tests.sh *)
  - Bash(bash .claude/skills/darwin-compat-check/scripts/verify.sh*)
---

# Darwin Compatibility Check

Run this when verifying that code still builds and passes tests on macOS. The
Yuzu team runs CI on Linux/Windows/macOS, but most development happens on
Linux and Windows, so Darwin-specific regressions slip through between runs.
This skill exists so the check is reproducible and the standing pitfalls are
one prompt away.

## When to use

- Windows-originated commits have landed on `origin/dev` and you need to
  verify macOS is still green.
- A change touches `meson.build`, any `.cpp`/`.hpp` file, or any SQLite store.
- A change modifies path comparisons (`fs::path`, `fs::canonical`, symlink
  handling).
- A change modifies Erlang `rebar3 ct` invocations or `prometheus_httpd`
  startup.
- You are about to commit a cross-platform fix and want to confirm nothing
  regressed before pushing.

## Quick verification

```bash
bash .claude/skills/darwin-compat-check/scripts/verify.sh
```

Runs the canonical sequence: fetch → status → pull (if tracking) → meson
reconfigure (only if `meson.build` changed) → meson compile → full test
suite. Exits non-zero on the first failure. Pass `--no-pull` to skip the
fast-forward step when you have local work in flight.

## Manual sequence

If you need finer control than the helper, run the steps by hand:

1. `git fetch origin && git status` — confirm branch state.
2. `git pull --ff-only` — fast-forward to latest.
3. `git diff HEAD~N..HEAD --stat` — review what changed.
4. Identify which previous Darwin fixes are still present in the new tree.
5. `meson setup builddir --reconfigure ...` — only if `meson.build` changed.
6. `meson compile -C builddir` — fix any new compile errors.
7. `bash scripts/run-tests.sh all` — fix any new test failures.
8. Commit clean with a Darwin-fix commit message.

## Diagnosing failures

Before digging into an unfamiliar failure, read `pitfalls.md` in this skill
directory. Most Darwin failures match one of five recurring patterns —
`/var` vs `/private/var` symlink, SQLite FULLMUTEX + application mutex,
`rebar3 ct --dir`, `curl -f` status-code contamination, or
`prometheus_httpd` startup order. If the failure is a new category, add it
to `pitfalls.md` as part of the fix.

## Reporting back

After fixing, hand a short report to the `cross-platform` subagent: what
broke, which pitfall it matched (or "new category"), and the commit SHA
that fixed it. This keeps the pitfall catalog and the subagent's prior
knowledge in sync.
