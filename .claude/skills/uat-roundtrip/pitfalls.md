# UAT Stack Standing Pitfalls

Recurring failure modes when running the Linux UAT stack. When the UAT
fails to come up or the 6 automated tests fail, check here first. If a
failure does not match, add it to this file as part of the fix.

## 1. Stale `/tmp/yuzu-uat` → session auth breaks on restart

**Symptom:** `authenticate()` succeeds (HTTP 200, Set-Cookie returned)
but `validate_session()` fails on every subsequent request (HTTP 401).
The login screen appears to work, then every dashboard action returns
401.

**Rule:** wipe `/tmp/yuzu-uat` before every UAT run. `scripts/linux-
start-UAT.sh` does this automatically; `scripts/uat-roundtrip/scripts/
roundtrip.sh` also enforces it.

The root cause is a known bug: restarting the server against an existing
data directory leaves stale SQLite session-related state that interacts
incorrectly with the in-memory `sessions_` map. Until that bug is fixed,
the wipe is load-bearing — do not disable it with `--no-wipe` unless you
have specifically verified the failure mode does not apply.

## 2. Missing server flags break gateway command forwarding

**Symptom:** Commands sent via the server REST API are accepted and
return a command ID, but the agent never receives them. The gateway
shows the agent as connected; the server shows the command queued to
`gw_pending_`. Response never arrives.

**Rule:** when running the stack with a gateway, the server needs **all
three** of these flags:

```bash
yuzu-server \
  --gateway-upstream 0.0.0.0:50055 \
  --gateway-mode \
  --gateway-command-addr localhost:50063
```

Each flag solves a distinct problem:

- `--gateway-upstream 0.0.0.0:50055` — enables the `GatewayUpstream`
  gRPC service so the gateway can proxy agent registrations and batch
  heartbeats to the server.
- `--gateway-mode` — relaxes Subscribe stream peer-mismatch validation.
  Gateway-proxied agents have Register and Subscribe peers that are both
  the gateway's address, not the agent's; without this flag the server
  rejects the Subscribe stream as a peer mismatch.
- `--gateway-command-addr localhost:50063` — points the server at the
  gateway's `ManagementService` for command forwarding. Without it,
  commands destined for gateway-connected agents are queued in
  `gw_pending_` but never forwarded, because the server doesn't know
  where to call `SendCommand`.

The dispatch flow in `server/core/src/agent_registry.cpp` `send_to()`:
- Agent has a local Subscribe stream → write directly (direct-connect).
- Agent has a `gateway_node` but no local stream → queue to `gw_pending_`.
- `forward_gateway_pending()` drains the queue via
  `gw_mgmt_stub_->SendCommand()`, which requires `--gateway-command-addr`.

## 3. Port conflicts from a prior un-torn-down run

**Symptom:** UAT start fails with
`bind: address already in use` on port 8080, 50051, 50055, 50061, or
50063. Or start "succeeds" but `status` shows no processes.

**Rule:** always run `bash scripts/linux-start-UAT.sh stop` before
starting a new run, even if you believe the previous run was already
torn down. The script is idempotent — `stop` on a clean state is a
no-op.

`roundtrip.sh` does this automatically. If ports are still bound after
`stop`, something outside the UAT is using them — check with:

```bash
ss -tlnp 'sport = :8080 or sport = :50051 or sport = :50055 \
          or sport = :50061 or sport = :50063'
```

## 4. `gateway/config/sys.config` drift

**Symptom:** Gateway starts, but agents fail to connect to port 50061
with `connection refused`, or the gateway binds a different port than
the server expects.

**Rule:** the gateway has **two** independent port configurations that
must match:

1. The `yuzu_gw` application config (`gateway/config/sys.config`).
2. The `grpcbox` `listen_opts` (also in `sys.config`, but under a
   separate `grpcbox` application key).

If you change one, you must change the other. They're configured
independently and there is no runtime cross-check.

```erlang
%% gateway/config/sys.config
[
 {yuzu_gw,
  [{agent_listen_port, 50061},     %% must match grpcbox below
   {upstream_addr, "127.0.0.1:50055"}]},
 {grpcbox,
  [{servers,
    [#{grpc_opts => #{service_protos => [...]},
       listen_opts => #{port => 50061}}]}]}  %% must match yuzu_gw above
].
```

## 5. Gateway port range: 5006x, not 5005x

**Symptom:** Gateway starts but fails to register with the server,
because it tries to bind a port the server is already using.

**Rule:** the gateway uses its own port range (5006x) to avoid
conflicts with the server (5005x) when both run on the same box. All
three components (server, gateway, agent) are designed to coexist on
one host using the default config.

If you need to rebind ports for a custom deployment, edit both
`gateway/config/sys.config` (see pitfall #4) and pass matching
`--gateway-upstream` / `--gateway-command-addr` flags to the server.

## 6. UAT credentials are regenerated every run

**Symptom:** You log in with credentials from a previous run and get
`invalid credentials`.

**Rule:** `scripts/linux-start-UAT.sh` generates a fresh
`yuzu-server.cfg` with PBKDF2-SHA256 hashed credentials on every run.
The fixed credentials are `admin` / `adminpassword1` — they are
deterministic across runs, but the hash in the config file is
regenerated, so any cookie or token from a prior run is invalidated.

This is by design — the UAT is meant to be reproducible from a clean
state. If you need a persistent credential for manual testing, start
the server outside the UAT script.

## Adding a new pitfall

When a UAT failure doesn't match any of the above, add a new section
with: symptom, rule, diagnostic command, and fix. Keep each entry
self-contained so future sessions can diagnose without reading the
rest of the file.
