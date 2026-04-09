# Meson Build Standing Pitfalls

Recurring failure modes when building Yuzu with Meson. When a build or
configure fails, check here first. If a failure doesn't match, add it
to this file as part of the fix.

## 1. Source file drift

**Symptom:** The project compiles successfully, but a newly added file
is silently excluded from the build. Runtime fails with a missing
symbol, or a test that should cover the new code passes vacuously.

**Rule:** every `.cpp` and `.hpp` file on disk must be referenced by a
`meson.build`. When you add, rename, or delete a source file, update
the `meson.build` in that directory in the same commit.

`verify.sh` enforces this with a drift scan: it walks `agents/`,
`server/`, `sdk/`, and `tests/`, and for every source file checks that
its filename appears in at least one `meson.build`. Any miss is a
hard failure.

Bad (file on disk, not referenced):
```
server/core/src/new_store.cpp    # exists
server/core/meson.build          # does NOT mention new_store.cpp
```

Good:
```meson
# server/core/meson.build
yuzu_server_sources = files(
  'src/main.cpp',
  'src/response_store.cpp',
  'src/new_store.cpp',   # added in same commit as src/new_store.cpp
)
```

## 2. vcpkg baseline drift

**Symptom:** CI builds succeed but a local build fails with
`version constraint cannot be satisfied` or `baseline not found`.

**Rule:** the `builtin-baseline` in `vcpkg.json` must be pinned to a
commit vcpkg knows about, and it should match the `vcpkgGitCommitId`
used by CI. The pinned baseline at time of writing is
`4b77da7fed37817f124936239197833469f1b9a8`.

The baseline is **required** because of the `version>=` constraint on
abseil. Without it, vcpkg resolves against HEAD, which drifts daily.

Fix: update both `vcpkg.json` `builtin-baseline` and
`.github/workflows/ci.yml` `vcpkgGitCommitId` in the same commit.

## 3. Platform-filtered dependency mis-use

**Symptom:** Build fails on Windows with OpenSSL link errors, or on
32-bit ARM with Catch2 not found.

**Rule:** some vcpkg ports are platform-filtered in `vcpkg.json`, and
code must respect those filters:

- **OpenSSL is skipped on Windows** (`"platform": "!windows"`). gRPC
  uses the native Windows crypto stack (schannel). Do **not** add
  `#include <openssl/...>` in code that compiles on Windows.
- **Catch2 is filtered to `x64 | arm64`** (not 32-bit ARM). The ARM64
  cross-compile CI job intentionally skips tests.
- **schannel is NOT a vcpkg port.** It's a Windows system library; do
  not add it to `vcpkg.json`.

If you need a dependency that's filtered out on a platform, gate the
code with `#ifdef` or move it to a platform-specific source list.

## 4. Windows: `vcvars64.bat` vs `setup_msvc_env.sh`

**Symptom:** On Windows/MSYS2, `.bat` wrapper scripts abort or produce
"cl.exe not found" even though MSVC is installed.

**Rule:** do **not** use `vcvars64.bat`. It returns exit code 1 due to
optional extension failures (Clang, bundled CMake, ConnectionManager)
even when cl.exe is set up correctly, and this causes `.bat` wrapper
scripts to misbehave.

Use `setup_msvc_env.sh` from MSYS2 bash — it sets MSVC paths directly
without invoking the broken batch file:

```bash
source ./setup_msvc_env.sh
meson compile -C builddir
```

## 5. Windows: Clang at `C:\Program Files\LLVM\bin` is wrong

**Symptom:** On Windows, meson or the compile fails in a way that
suggests a non-MSVC compiler was selected.

**Rule:** the project must be built with MSVC `cl.exe`, not the
standalone LLVM Clang distribution. `setup_msvc_env.sh` sets `PATH` and
`CC`/`CXX` to point at the MSVC toolchain explicitly. If you see
`C:\Program Files\LLVM\bin` in the build log, something has
overridden the env — re-source `setup_msvc_env.sh` in a clean shell.

## 6. ARM64 cross-compile with `-Dbuild_tests=true`

**Symptom:** ARM64 cross-compile fails because Catch2 isn't available.

**Rule:** the ARM64 cross-compile CI job intentionally skips tests.
Catch2 is platform-filtered to `x64 | arm64` but the 32-bit ARM triplet
doesn't ship it, and the cross file doesn't carry the right search
paths. Do not enable `-Dbuild_tests=true` on ARM64 cross builds.

If you need tests on ARM64, run them natively on an ARM64 host, not
via cross-compile.

## 7. Reconfigure required after `meson.build` changes

**Symptom:** `meson compile -C builddir` reports success but the new
file or target is not actually built, or you see stale errors
referencing a file that was deleted.

**Rule:** meson re-reads `meson.build` automatically for most changes,
but certain structural edits (new `custom_target`, new dependency,
compiler option change) require an explicit reconfigure:

```bash
meson setup builddir --reconfigure
meson compile -C builddir
```

`verify.sh` detects recent `meson.build` changes and runs
`--reconfigure` automatically.

## 8. Proto codegen: flattened include paths

**Symptom:** A generated protobuf header is not found, or an include
like `#include "yuzu/common/v1/common.pb.h"` fails.

**Rule:** `proto/gen_proto.py` rewrites `#include` paths in generated
files to flatten subdirectory prefixes. Include generated headers as
`"common.pb.h"`, not `"yuzu/common/v1/common.pb.h"`. The `yuzu_proto`
static library exposes the flattened output dir on its
`include_directories`, which is why the flattened form works.

If you add a new `.proto`, the codegen script picks it up automatically
— but you still need to reconfigure meson (see pitfall #7).

## Adding a new pitfall

When a build or configure failure doesn't match any of the above, add
a new section with: symptom, rule, bad example, good example. Keep
each entry self-contained.
