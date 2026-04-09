---
name: meson-verify
description: Verify the Meson build is consistent after source file changes. Use whenever .cpp/.hpp/.proto files are added, removed, or renamed — the affected directory's meson.build must list them. Runs compile and detects source-file drift (files on disk but not referenced by any meson.build).
allowed-tools:
  - Bash(bash .claude/skills/meson-verify/scripts/verify.sh*)
  - Bash(meson setup *)
  - Bash(meson compile *)
  - Bash(meson configure *)
  - Bash(ninja *)
---

# Meson Build Verification

Use this skill after adding, removing, or renaming any source file.
Meson is the sole build system for Yuzu, and **every time a source file
changes, the affected directory's `meson.build` must be updated**. A
file on disk that isn't referenced by any `meson.build` will silently
be excluded from the build — the project compiles, ships, and fails at
runtime with a missing symbol.

## When to use

- You added a new `.cpp` or `.hpp` file anywhere under `agents/`,
  `server/`, `sdk/`, or `tests/`.
- You renamed or deleted a source file.
- You added a new plugin under `agents/plugins/`.
- You added a new `.proto` file under `proto/`.
- You changed a `meson.build` and want to confirm nothing regressed.
- You are about to commit a file-layout change.

## Quick verification

```bash
bash .claude/skills/meson-verify/scripts/verify.sh
```

Runs, in order:
1. **Drift detection** — scans `agents/`, `server/`, `sdk/`, `tests/` for
   `.cpp` / `.hpp` files not referenced by any `meson.build`. Any drift
   is a hard failure.
2. **Reconfigure if needed** — if any `meson.build` has changed since
   the last configure, runs `meson setup builddir --reconfigure`.
3. **Compile** — `meson compile -C builddir`.

Exits non-zero on the first failure. Pass `--no-drift` to skip drift
detection (only for the rare case where a file is intentionally
excluded, e.g. an example that's built via a different target).

## Manual sequence

```bash
# After adding server/core/src/new_store.cpp:
# 1. Edit server/core/meson.build — add new_store.cpp to the source list.
# 2. Reconfigure (only if meson.build changed):
meson setup builddir --reconfigure
# 3. Compile:
meson compile -C builddir
# 4. Run affected tests:
meson test -C builddir --print-errorlogs
```

## Diagnosing failures

Before investigating a build failure, read `pitfalls.md`. The common
categories:

1. **Source drift** — file on disk, not in `meson.build`.
2. **vcpkg baseline drift** — `vcpkg.json` `builtin-baseline` doesn't
   match CI's `vcpkgGitCommitId`.
3. **Platform-filtered dependency mis-use** — OpenSSL on Windows,
   Catch2 on 32-bit ARM.
4. **Windows toolchain misuse** — `vcvars64.bat` instead of
   `setup_msvc_env.sh`; or Clang being picked up from `C:\Program
   Files\LLVM\bin` instead of MSVC cl.exe.
5. **ARM64 cross-compile with `-Dbuild_tests=true`** — intentionally
   unsupported; Catch2 is platform-filtered out of the ARM64 triplet.
6. **Reconfigure required** — `meson.build` changed but `meson setup
   --reconfigure` wasn't run.

If the failure doesn't match, add a new section to `pitfalls.md`.

## Reporting back

After fixing, hand the `build-ci`, `cpp-expert`, or `architect` subagent
a short report: which pitfall matched (or "new category"), the commit
SHA of the fix, and — if it was a new category — a one-paragraph
addition for `pitfalls.md`.
