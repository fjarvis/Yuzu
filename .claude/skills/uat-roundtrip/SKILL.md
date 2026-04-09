---
name: uat-roundtrip
description: Run the Linux UAT stack (server + gateway + agent) and verify end-to-end command round-trip. Use before committing changes to agent_registry, gateway command forwarding, gRPC services, enrollment flow, or any server↔agent protocol. Wipes /tmp/yuzu-uat to work around the stale-DB session auth bug.
allowed-tools:
  - Bash(bash scripts/linux-start-UAT.sh*)
  - Bash(bash .claude/skills/uat-roundtrip/scripts/roundtrip.sh*)
  - Bash(ss -tlnp*)
  - Bash(pgrep *)
  - Bash(ls /tmp/yuzu-uat*)
---

# UAT Round-Trip Verification

Use this skill to stand up the full Yuzu stack on Linux
(server + gateway + agent) and verify that a command sent to the server
reaches the agent and returns a response. This is the canonical
end-to-end check for anything that touches the server↔gateway↔agent
protocol path.

## When to use

- You changed `server/core/src/agent_registry.cpp` (dispatch flow) or
  the gateway command forwarding path.
- You added a new gRPC RPC or changed an existing one in `proto/`.
- You touched enrollment (tiered enrollment, tokens, pending approvals).
- You changed the subscribe stream, heartbeat, or command response path.
- You changed `gateway/` supervision, command fanout, or batch heartbeat
  aggregation.
- You are about to cut a release candidate and need a smoke test.

## Quick verification

```bash
bash .claude/skills/uat-roundtrip/scripts/roundtrip.sh
```

Wraps `scripts/linux-start-UAT.sh` with the canonical sequence:
preflight port check → `stop` (clean slate) → wipe `/tmp/yuzu-uat` →
`start` (runs the 6 automated round-trip tests) → `status` → optional
`stop` at the end. Exits non-zero if any step or any of the 6 tests fail.

Flags:
- `--keep-running` — leave the stack up after tests pass (useful for
  manual inspection).
- `--no-wipe` — skip the `/tmp/yuzu-uat` wipe (only safe if you know the
  stale-DB bug doesn't apply to your change).

## Manual sequence

```bash
bash scripts/linux-start-UAT.sh stop       # clean slate
rm -rf /tmp/yuzu-uat                        # stale-DB workaround
bash scripts/linux-start-UAT.sh             # start + 6 round-trip tests
bash scripts/linux-start-UAT.sh status      # verify processes are alive
bash scripts/linux-start-UAT.sh stop        # teardown
```

## Port expectations

The stack binds these ports. The preflight check in `roundtrip.sh`
verifies they are free before starting — port conflicts are the most
common reason the UAT fails to come up.

| Port  | Component | Purpose                                  |
|-------|-----------|------------------------------------------|
| 8080  | Server    | Web dashboard + REST API                 |
| 50051 | Server    | Agent gRPC (direct connections)          |
| 50052 | Server    | Management gRPC                          |
| 50055 | Server    | Gateway upstream (registration, heartbeats) |
| 50061 | Gateway   | Agent-facing gRPC (agents connect here)  |
| 50063 | Gateway   | Management/command forwarding            |
| 8081  | Gateway   | Health/readiness (`/healthz`, `/readyz`) |
| 9568  | Gateway   | Prometheus metrics                       |

Note: the gateway uses port **50061** for agent-facing gRPC in the UAT
config, not 50051, to avoid colliding with the server's direct-agent
port when both run on the same host. See `gateway/config/sys.config`
and pitfall #4.

## Diagnosing failures

Before investigating a UAT failure, read `pitfalls.md` — five recurring
failure modes cover almost every UAT breakage:

1. Stale `/tmp/yuzu-uat` → session auth returns 200 then 401.
2. Missing server `--gateway-upstream` / `--gateway-mode` /
   `--gateway-command-addr` flags → commands queue but never forward.
3. Port conflicts (prior run not torn down, or another process on 8080).
4. `gateway/config/sys.config` drift between `yuzu_gw` app config and
   `grpcbox` `listen_opts`.
5. Gateway config not matching the server's gateway-upstream expectation.

If the failure doesn't match any of these, it's a new category. Add it
to `pitfalls.md` as part of the fix.

## Reporting back

After fixing, hand the `sre`, `release-deploy`, or `quality-engineer`
subagent a short report: which pitfall matched (or "new category"), the
commit SHA fixing it, and — if a new category — a one-paragraph addition
for `pitfalls.md`.
