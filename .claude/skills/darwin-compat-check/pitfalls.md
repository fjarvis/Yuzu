# Darwin Standing Pitfalls

Recurring macOS-specific failure modes that are **not** caught by Linux or
Windows CI. When a Darwin test fails, check here first — most failures
match one of these patterns. If a failure does not match, add it to this
file as part of the fix.

## 1. Path comparisons: `/var` vs `/private/var`

macOS symlinks `/var` → `/private/var`. Any test that compares an absolute
path to a constant string will fail on Darwin if one side went through the
symlink and the other did not.

**Rule:** always call `std::filesystem::canonical()` on both sides before
comparing paths in tests.

Bad:
```cpp
REQUIRE(cfg.data_dir == "/var/lib/yuzu");
```

Good:
```cpp
REQUIRE(fs::canonical(cfg.data_dir) == fs::canonical("/var/lib/yuzu"));
```

The same trap appears with `/tmp` → `/private/tmp` in some macOS versions.
Canonicalize first, compare second.

## 2. SQLite concurrency: FULLMUTEX + application mutex

All stores must open the database with `sqlite3_open_v2()` and the flags:

```cpp
SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
```

**Plain `sqlite3_open()` is not acceptable.** FULLMUTEX serializes low-level
SQLite access but does **not** make `bind → step → reset` sequences
atomic. Application-level `std::shared_mutex` is therefore **required**
(not optional, not defense-in-depth-only) for any store that caches
prepared statements.

Canonical store pattern:

```cpp
class FooStore {
 public:
  explicit FooStore(std::string_view path);
  ~FooStore();

 private:
  mutable std::shared_mutex mtx_;
  sqlite3* db_ = nullptr;
  sqlite3_stmt* insert_stmt_ = nullptr;
};

FooStore::FooStore(std::string_view path) {
  int rc = sqlite3_open_v2(
      std::string(path).c_str(), &db_,
      SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
      nullptr);
  // ... prepare statements ...
}
```

Writes take `std::unique_lock`, reads take `std::shared_lock`. See
`server/core/src/response_store.hpp` for the canonical implementation.

## 3. Erlang rebar3 ct: `--dir` is mandatory

When running gateway Common Test suites, always pass `--dir` together with
`--suite`:

```bash
rebar3 ct --dir apps/yuzu_gw/test --suite some_SUITE
```

Without `--dir`, rebar3 cannot locate the suite and silently reports
success with zero tests run. This is a particularly nasty failure because
it looks like a clean pass in CI logs.

## 4. `curl -f` contaminates status codes in tests

Do **not** use `curl -f` in test scripts where a 4xx response is an
acceptable outcome. `-f` makes curl exit non-zero on 4xx, which causes
`|| echo "000"` fallbacks to overwrite the real status code variable.

Bad:
```bash
status=$(curl -f -s -o /dev/null -w "%{http_code}" "$url" || echo "000")
# If the server returns 401, $status is "000", not "401".
```

Good:
```bash
status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
# $status is whatever the server actually returned.
```

Only use `-f` when a 4xx genuinely indicates a test failure (e.g. fetching
a static asset that must exist).

## 5. `prometheus_httpd` startup sequence

Use `prometheus_httpd:start/0` — `start/1` does not exist:

```erlang
application:set_env(prometheus, prometheus_http,
                    [{port, Port}, {path, "/metrics"}]),
application:ensure_all_started(prometheus_httpd),
prometheus_httpd:start().
```

`ensure_all_started(prometheus_httpd)` must run **before** `start/0` so
that `prometheus_http_impl:setup/0` is invoked before the first scrape.
Getting the order wrong produces a scrape endpoint that returns 404 for
the first few requests, then begins working — flaky and confusing.

## Adding a new pitfall

When a Darwin failure doesn't match any of the above, add a new section
with: symptom (what broke and how), rule (the one-line fix), bad example,
good example. Keep each entry self-contained so future sessions can
diagnose without reading the rest of the file.
