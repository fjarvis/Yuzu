# Erlang Gateway Standing Pitfalls

Recurring dialyzer and compile failure modes in the Yuzu gateway. When a
`rebar3 dialyzer` run fails, check here first — most warnings match one
of these patterns. If a failure does not match, add it to this file as
part of the fix.

## 1. Transitive dependency not listed in `applications`

**Symptom:** Dialyzer cannot find a module or function in its PLT, even
though the code compiles and runs fine.

**Rule:** if you call a function from a transitive dependency directly,
add that dependency to the `applications` list in `yuzu_gw.app.src`.
Compilation does not require it (rebar3 resolves transitively); dialyzer
does, because the PLT is built from the declared application set.

**Canonical example:** `ctx:background/0` is used to create gRPC call
contexts for grpcbox RPCs. `ctx` is a transitive dep of `grpcbox`, but
because we call `ctx:background/0` directly, it must appear in
`yuzu_gw.app.src`:

```erlang
{application, yuzu_gw,
 [{description, "Yuzu gateway"},
  {vsn, "0.1.0"},
  {applications,
   [kernel, stdlib,
    grpcbox,
    ctx,          %% transitive dep of grpcbox, but called directly
    prometheus,
    prometheus_httpd]},
  ...]}.
```

Dialyzer will emit `Unknown function ctx:background/0` without this entry.

## 2. `-spec` contract violated in a catch/fallback path

**Symptom:** Dialyzer flags a function call site with
`Function will never be called with these arguments` or
`Call does not respect the declared type`.

**Rule:** respect `-spec` contracts even in catch/fallback paths. A spec
of `-spec f(map()) -> ok` means `f(some_atom)` is a type violation, and
dialyzer will reject it regardless of whether the path is reachable at
runtime.

Bad:
```erlang
-spec queue_heartbeat(map()) -> ok.
queue_heartbeat(HB) when is_map(HB) -> ...;
queue_heartbeat(flush) -> flush_sync().  %% spec violation
```

Good:
```erlang
-spec queue_heartbeat(map()) -> ok.
queue_heartbeat(HB) when is_map(HB) -> ...;
%% If you need a sentinel, use a separate function with its own spec.
```

## 3. Catchall clauses on structurally-unreachable states

**Symptom:** Dialyzer warns
`The pattern _ can never match since previous clauses completely covered
the type`.

**Rule:** don't add catchall clauses for states that the type system
already proves unreachable. Dialyzer reads the full type and knows the
pattern is dead code.

**Canonical example:** the circuit breaker's `on_success/1` and
`on_failure/1` only receive states `closed` or `half_open` because
`check_circuit/1` rejects `open` before the RPC runs. A catchall on
`open` is dead code:

Bad:
```erlang
on_success(closed)    -> ...;
on_success(half_open) -> ...;
on_success(_)         -> ok.  %% dialyzer: dead
```

Good:
```erlang
-spec on_success(closed | half_open) -> ok.
on_success(closed)    -> ...;
on_success(half_open) -> ....
```

## 4. Benign `gpb` rebar3 plugin warning

**Symptom:** `Plugin gpb does not export init/1` during `rebar3 compile`.

**Rule:** ignore it. `gpb` is used via the `grpc` rebar3 config section,
not as a rebar3 plugin in the `plugins` list. The warning is a harmless
misfire from rebar3's plugin discovery and does not block the build. Do
**not** attempt to "fix" it by adding a `plugins` entry — that breaks the
actual `grpc` config.

## 5. Stray `.beam` files and crash dumps

**Symptom:** `.beam` files or `erl_crash.dump` in `gateway/`,
`gateway/apps/yuzu_gw/`, or any source directory outside `_build/`.

**Rule:** these are build/runtime artifacts. They must be gitignored or
deleted before commit. Loose `.beam` files in source directories cause
dialyzer to pick up stale bytecode and produce phantom warnings;
`erl_crash.dump` is a runtime artifact from a previous EUnit failure and
should never be committed.

The `verify.sh` helper scans for these and reports them before running
dialyzer.

## 6. Shutdown flush: `flush_sync/0` only

**Symptom:** heartbeat buffer is corrupted on shutdown, or dialyzer warns
about `queue_heartbeat/1` being called with a non-map argument.

**Rule:** during `stop/1`, drain the heartbeat buffer with `flush_sync/0`.
Do **not** fall back to calling `queue_heartbeat/1` with a sentinel atom
like `flush` — that violates the `-spec queue_heartbeat(map()) -> ok`
contract (pitfall #2) and corrupts the buffer.

If `flush_sync/0` itself fails, the process is already dead and the
buffer is lost. There is no graceful recovery — accept the loss and log
it. Do not invent a workaround that violates the spec.

## 7. `rebar3 ct` requires `--dir`

**Symptom:** `rebar3 ct --suite some_SUITE` silently reports success with
zero tests run.

**Rule:** always pass `--dir apps/yuzu_gw/test` together with `--suite`:

```bash
rebar3 ct --dir apps/yuzu_gw/test --suite some_SUITE
```

Without `--dir`, rebar3 cannot locate the suite files in the umbrella
project layout and passes vacuously. This is a particularly nasty failure
because it looks like a clean pass in CI logs.

## Adding a new pitfall

When a dialyzer or compile failure doesn't match any of the above, add a
new section with: symptom, rule, bad example, good example. Keep each
entry self-contained so future sessions can diagnose without reading the
rest of the file.
