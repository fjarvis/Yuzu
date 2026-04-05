# DEX Business Requirements Gap Analysis

**Date:** 2026-04-05
**Source:** Business Requirements Document — IO EUO Aternity RFP
**Assessed Against:** Yuzu Endpoint Management Platform (current codebase)

---

## Executive Summary

This document assesses Yuzu's readiness against a real enterprise Digital Employee Experience (DEX) RFP containing ~120 requirements across 20 categories. Yuzu is an **endpoint management platform**, not a DEX tool — so the overlap is partial by design. However, many DEX requirements map to capabilities Yuzu already has or could extend.

**Overall Coverage:**

| Rating | Count | Percentage |
|--------|-------|------------|
| Full / Strong | ~35 | ~29% |
| Partial | ~25 | ~21% |
| Gap (not implemented) | ~60 | ~50% |

Yuzu's strengths are in endpoint management, security, policy/compliance, and scripting/remediation. The largest gaps are in end-user experience monitoring, application performance metrics, mobile, VDI, AI/ML analytics, ITSM integration, and remote support.

---

## Category-by-Category Assessment

### 1. Multi Platform Support

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Windows | **Full** | Native agent with WMI, registry, BitLocker, SCCM, MSI plugins |
| Mac | **Full** | Native agent with Keychain, launchd, airport WiFi |
| Linux | **Full** | Native agent with systemd, /proc, apt/rpm |
| iOS | **Gap** | No mobile agent — not on roadmap |
| Android | **Gap** | No mobile agent — not on roadmap |
| Windows Servers | **Full** | Same agent binary works on Server SKUs |
| Linux Servers | **Full** | Same agent binary works on server distros |
| Storage Servers | **Partial** | Agent runs on storage servers but no storage-specific monitoring |

### 2. Device & Endpoint Performance Metrics

| Requirement | Yuzu Status | Notes |
|---|---|---|
| CPU Utilization | **Partial** | `hardware` plugin reports CPU info; `tar` captures process snapshots; no continuous CPU % metric |
| Memory Utilization | **Partial** | `hardware` plugin reports total RAM; `tar` captures snapshots; no continuous tracking |
| Disk I/O latency and throughput | **Gap** | No disk I/O performance monitoring |
| Network Latency and Packet Loss | **Partial** | `network_diag` plugin has ping; no continuous latency/packet loss tracking |
| GPU Utilization | **Gap** | No GPU monitoring |
| NPU Utilization | **Gap** | No NPU monitoring |
| CPU Throttling | **Gap** | No thermal/throttle detection |
| Disk Size and utilization | **Partial** | `hardware` plugin reports disk info; no continuous utilization tracking |
| Battery Health | **Gap** | No battery monitoring |

### 3. Application (Desktop & Web) Usage & Performance Metrics

| Requirement | Yuzu Status | Notes |
|---|---|---|
| App-specific resource consumption | **Gap** | No per-app resource tracking |
| Single/Multi Thread CPU Monitoring | **Gap** | No per-core/thread CPU monitoring |
| GPU & NPU requirement | **Gap** | No GPU/NPU analysis |
| Application Performance | **Gap** | No APM capabilities |
| Performance Tuning | **Gap** | No automated performance tuning |
| Application Error Rates | **Gap** | No app error rate tracking |
| App process hang and unresponsive events | **Gap** | No app hang detection |
| App Crashes (foreground vs background) | **Gap** | No app crash detection |
| App Usage pattern analysis | **Gap** | No app usage pattern analytics |
| Java Usage | **Gap** | No JVM monitoring |
| App Anomalies | **Gap** | No anomaly detection |
| Application Auto Discovery | **Partial** | `installed_apps` plugin enumerates installed software; no runtime auto-discovery |
| Foreground vs Background Agents | **Gap** | No foreground/background app tracking |

### 4. End User Experience Metrics

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Application Launch Time | **Gap** | No app launch time measurement |
| User Logon/Logoff Duration | **Partial** | `users` plugin tracks login history timestamps; no duration calculation |
| Machine Launch and Shutdown time | **Gap** | No boot/shutdown timing |
| Session Responsiveness Score | **Gap** | No UX scoring |
| Screen Refresh Latency | **Gap** | No screen rendering metrics |
| Input Latency | **Gap** | No keyboard/mouse latency tracking |
| Application responsiveness | **Gap** | No UI responsiveness metrics |

### 5. Network & Connectivity Performance Metrics

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Bandwidth Usage | **Gap** | No bandwidth monitoring |
| VPN or Gateway Latency | **Gap** | No VPN latency tracking |
| Network Jitter and Fluctuations | **Gap** | No jitter measurement |
| Round-Trip Time (RTT) to key resources | **Partial** | `network_actions` plugin supports ping; no continuous RTT monitoring |
| Connection drops per session | **Gap** | No session drop tracking |
| Intel Wi-Fi and Thunderbolt Analytics | **Gap** | No Intel-specific analytics |
| Real-time call/video insights | **Gap** | No UC/call quality monitoring |
| App usage network metrics | **Gap** | No per-app network metrics |
| Device Discovery | **Full** | `discovery` plugin with ARP scan + ping sweep, DiscoveryStore for persistence |
| Latency information | **Partial** | Ping available; no continuous latency dashboard |

### 6. Reporting & Observability

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Crash Detection | **Gap** | No application crash detection |
| Crash Logging | **Gap** | No crash log collection |
| Root Cause Analysis | **Gap** | No automated RCA |
| Real-Time Monitoring | **Partial** | Dashboard with SSE streaming, heartbeat monitoring; not DEX-style real-time |
| Dashboard Customisation | **Partial** | HTMX dashboard exists but is not customisable per-user |
| Real-Time Alerts | **Partial** | NotificationStore with info/warn/error levels; no threshold-based alerting engine |
| Application Non-Usage Data for License Harvesting | **Partial** | `installed_apps` lists software; no usage tracking for license reclamation |
| Integration with Monitoring tools | **Full** | Prometheus `/metrics` endpoint, Grafana templates, ClickHouse sink, webhook events |
| Data Aggregation & Granularity | **Full** | ResponseStore with COUNT/SUM/AVG/MIN/MAX/GROUP BY, CSV/JSON export |

### 7. Security and Privacy

| Requirement | Yuzu Status | Notes |
|---|---|---|
| GDPR compliance | **Partial** | Audit log with retention; no data deletion workflow or consent management |
| Remote action security | **Full** | mTLS, command signing via approval workflows, RBAC |
| Data Encryption | **Full** | mTLS in transit, SQLite WAL storage, HTTPS by default, BitLocker/LUKS/FileVault monitoring |
| Granular Role/Action based access privileges | **Full** | 6 roles, 14 securable types, per-operation permissions, deny-override, management-group scoping |

### 8. Endpoint Management

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Endpoint Configuration | **Full** | Policy engine, instruction execution, script_exec plugin, registry plugin |
| Device & Driver Monitoring | **Partial** | `hardware` plugin reports hardware inventory; no driver-specific monitoring |
| Dynamic Device Group Creation | **Full** | Management groups with scope expressions (AND/OR/NOT, tags, OS, hostname, FQDN) |
| Policy Management | **Full** | PolicyStore with YAML definitions, CEL expressions, check/fix/postCheck pattern |
| Centralised Management | **Full** | Single server control plane with web dashboard, REST API, gRPC |
| Crash Detection | **Gap** | No app crash detection |
| Crash Logging | **Gap** | No crash log aggregation |

### 9. Self-Healing & Remediation

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Self-Healing Policies | **Full** | Policy engine with check/fix/postCheck pattern, auto-remediation triggers |
| OoB remediations | **Partial** | Agent executes locally when connected; no true out-of-band (e.g., IPMI/AMT) |
| Remediation capability — Scripting | **Full** | `script_exec` plugin: PowerShell, bash, Python with timeout, error handling |
| Remediation — Secure credential management | **Partial** | mTLS certs, Windows cert store; no vault/credential injection for scripts |
| Remediation — Error handling | **Full** | `std::expected<T,E>` error model, per-device error tracking in ResponseStore |
| Remediation — Pre/Post execution validation | **Full** | Policy engine check/fix/postCheck pattern is exactly this |
| Low-code/Drag and Drop workflow builder | **Gap** | No visual workflow builder — YAML definitions only |
| Pre-built component libraries | **Partial** | 44 plugins serve as building blocks; ProductPacks bundle definitions |
| Custom component creation | **Full** | Plugin SDK with stable C ABI, CRTP C++ wrapper, YUZU_PLUGIN_EXPORT |
| Workflow versioning and rollback | **Partial** | Instruction definitions are versioned; no rollback mechanism |
| Custom Monitoring Scripts | **Full** | `script_exec` plugin + trigger engine for continuous monitoring |
| Self-Healing workflows | **Full** | Trigger → instruction → policy evaluation chain |
| Runbook and Multi-Layer Decision Trees | **Partial** | Instruction hierarchies with parent/child follow-up; no visual decision tree |
| Offline Remediation | **Partial** | Trigger engine runs locally on agent; commands queued until reconnect |
| Self-Healing Policies | **Full** | Policy engine guaranteed-state enforcement |

### 10. Performance Benchmarking for Machines

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Overall device Performance benchmarking | **Gap** | No benchmarking capability |
| Hardware Benchmarking | **Gap** | No hardware benchmarks |
| Software Benchmarking | **Gap** | No software benchmarks |
| Boot Time | **Gap** | No boot time measurement |
| Login and Logout Times | **Partial** | `users` plugin has session history; no duration benchmarking |
| Baseline vanilla and layered image | **Gap** | No image baselining |
| Boot Components & Contribution to bootup time | **Gap** | No boot component analysis |

### 11. Application Usage Benchmarking

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Usage Analytics | **Gap** | No app usage tracking |
| Usage Patterns Analysis | **Gap** | No usage pattern analytics |
| Time to Launch | **Gap** | No app launch time measurement |

### 12. Intelligent Service Desk & AI Support

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Predictive Analysis | **Gap** | No ML/AI predictive engine |
| Performance Optimisation | **Gap** | No AI-driven optimization |
| Proactive Issue Resolution | **Partial** | Policy engine auto-remediates known states; no AI-driven proactive resolution |
| Automated Diagnostics | **Partial** | `diagnostics` plugin + `tar` timeline; not AI-powered |
| Proactive Alerts | **Partial** | NotificationStore + webhooks; no predictive alerting |
| App Crash/Down Detection & Blast Radius | **Gap** | No crash detection or blast radius analysis |
| Real-time Recommendations to End-user | **Gap** | No end-user recommendation engine |

### 13. Employee Sentiment Analysis

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Sentiment Analysis | **Gap** | No sentiment analysis |
| Sentiment Tracking | **Gap** | No sentiment tracking |
| Actionable Insights | **Gap** | No AI insight generation |
| User Feedback | **Partial** | `interaction` plugin supports message boxes and text input dialogs |
| Survey Capability | **Partial** | `interaction` plugin has ShowSurvey action (basic); advanced survey planned |

### 14. Sustainability Information

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Power usage | **Gap** | No power consumption monitoring |
| CPU power usage | **Gap** | No CPU power metering |
| GPU power usage | **Gap** | No GPU power metering |
| Full End to End visibility of ESG | **Gap** | No ESG/sustainability features |

### 15. User Experience

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Desktop client to view/manage desktop | **Gap** | Web dashboard only — no native desktop management client |

### 16. Capacity Planning

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Device Configuration Recommendations | **Gap** | No AI-driven config recommendations |
| Workprofile Persona Determination | **Gap** | No persona/workprofile classification |

### 17. Automated Test Capabilities

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Synthetic Monitoring | **Gap** | No synthetic transaction monitoring |
| Load testing | **Gap** | No load testing capability from endpoints |

### 18. Automated Ticketing (ITSM)

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Automated Ticketing | **Gap** | ServiceNow connector planned (Phase 9.5) but not implemented |
| Ticket Categorisation | **Gap** | No ticketing |
| Ticket Prioritisation | **Gap** | No ticketing |
| AI-Powered Automation | **Gap** | No AI automation for tickets |
| Predictive Analysis | **Gap** | No predictive analytics |

### 19. SSO & Identity

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Single Sign-On (SAML 2.0) | **Partial** | OIDC/PKCE implemented; no SAML 2.0 support |
| Integration with Entra ID | **Full** | Microsoft Graph API OAuth2 flow, user/group sync, group-to-role mapping |
| GDPR compliance | **Partial** | Audit trail exists; no data subject rights workflow |

### 20. Risk and Compliance Level

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Unauthorized app usage | **Partial** | `installed_apps` can enumerate; no runtime unauthorized usage detection |
| Failed Logon attempts | **Partial** | `event_logs` plugin can query Windows security events; no dedicated tracking |
| Shadow IT detection | **Partial** | `discovery` plugin finds unmanaged devices; no app-level shadow IT |
| Vulnerability Detection | **Full** | `vuln_scan` plugin with NVD CVE matching |
| Policy compliance violations | **Full** | Policy engine with per-agent compliance tracking and dashboard |

### 21. Remote Support Capabilities

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Remote desktop connection | **Gap** | No remote desktop/VNC/RDP capability |
| File transfer | **Partial** | `content_dist` plugin for server-to-agent file delivery; `filesystem` plugin for read/write |
| Remote troubleshooting | **Partial** | Remote script execution, log retrieval, diagnostics; not interactive |
| Quick Insights through Browser Plugin | **Gap** | No browser extension |
| Session recording | **Gap** | No session recording |

### 22. Virtual Infrastructure Level

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Server CPU, Memory and Storage Usage | **Partial** | ProcessHealthSampler for server self-monitoring; no VM host monitoring |
| Host Density | **Gap** | No VM density tracking |
| Storage Latency | **Gap** | No storage latency monitoring |
| Connection broker performance | **Gap** | No VDI broker monitoring |
| Endpoint Resource Contention | **Gap** | No contention detection |
| Session disconnects and reconnects | **Partial** | Agent reconnect tracking exists; no VDI session tracking |
| Number of session crashes | **Gap** | No VDI session crash tracking |
| vROps feed | **Gap** | No VMware integration |
| Citrix Integration | **Gap** | No Citrix integration |
| Thin Client Agent (eLux OS) | **Gap** | No thin client support |
| Hypervisor resource Constraints | **Gap** | No hypervisor monitoring; vCenter connector planned (Phase 14.3) |

### 23. Integrations

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Seamless Integration support (ITSM) | **Gap** | ServiceNow connector planned but not built |
| API availability | **Full** | 70+ REST endpoints, gRPC ManagementService, MCP server, OpenAPI spec |
| Collaboration Tool Integration (Zoom/Teams) | **Gap** | No Zoom/Teams integration |
| Webhooks Integration | **Full** | WebhookStore with HMAC-SHA256 signing, event filtering, async delivery, delivery history |

### 24. Mobile Experience Monitoring

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Mobile User Experience | **Gap** | No mobile agent or monitoring |
| Remediations on Mobile | **Gap** | No mobile support |
| Application Error Rates (mobile) | **Gap** | No mobile monitoring |
| App process hang (mobile) | **Gap** | No mobile monitoring |

### 25. User Behaviour and Adoption Level

| Requirement | Yuzu Status | Notes |
|---|---|---|
| Active/Idle time per user or session | **Gap** | No user activity tracking |
| Most Used applications | **Gap** | No app usage ranking |
| Session duration trends | **Partial** | `users` plugin tracks session history; no trend analysis |
| Number of simultaneous sessions | **Gap** | No concurrent session tracking |
| User Productivity Impact Scores | **Gap** | No productivity scoring |
| Click-to-Render | **Gap** | No UI rendering metrics |
| User Interaction Analysis | **Gap** | No interaction pattern analysis |

---

## Summary: Strongest and Weakest Areas

### Where Yuzu is strong (Full/Partial coverage)
1. **Security & Privacy** — mTLS, RBAC, encryption, vulnerability scanning
2. **Endpoint Management** — policy engine, dynamic groups, configuration management
3. **Self-Healing & Remediation** — policy check/fix/postCheck, scripting, triggers, offline execution
4. **Integrations (API/Webhooks)** — 70+ REST endpoints, gRPC, webhooks, MCP, Prometheus
5. **Multi-Platform (desktop)** — Windows, macOS, Linux with deep OS-specific plugins
6. **Risk & Compliance** — vulnerability scanning, policy compliance, audit trail
7. **Reporting infrastructure** — response aggregation, CSV/JSON export, Prometheus metrics

### Where Yuzu has significant gaps
1. **End-User Experience Monitoring** — no app launch times, input latency, responsiveness scores, click-to-render
2. **Application Performance Monitoring** — no crash detection, hang detection, error rates, usage analytics
3. **Mobile** — no iOS/Android support at all
4. **VDI/Virtual Infrastructure** — no Citrix, VMware, VDI session monitoring
5. **AI/ML Analytics** — no predictive analysis, anomaly detection, sentiment analysis, recommendations
6. **ITSM Integration** — no ticketing, ServiceNow/Jira connectors (planned)
7. **Remote Support** — no remote desktop, session recording
8. **Sustainability/Power** — no power consumption, battery, or ESG monitoring
9. **Performance Benchmarking** — no boot time, login time, hardware/software benchmarks
10. **Network Performance** — no continuous bandwidth, jitter, VPN latency, call quality metrics
11. **User Behaviour Analytics** — no productivity scores, usage patterns, adoption metrics
12. **Desktop Client / Low-code Builder** — web-only, YAML-only workflow definitions

---

## Strategic Assessment

Yuzu is fundamentally an **endpoint management and compliance platform** — it excels at the "manage, secure, and remediate" aspects of the DEX requirements. It is **not** a Digital Employee Experience monitoring tool, which focuses on passive observation of user experience metrics (app performance, UI responsiveness, sentiment).

### To close the gap, Yuzu would need:

**High-impact, feasible additions (extend existing architecture):**
- Continuous device performance metrics plugin (CPU %, memory %, disk I/O) — extends `hardware`/`tar`
- App usage and process monitoring plugin — extends `processes`/`procfetch`
- Boot/login time measurement — extends `event_logs` (Windows) or `tar`
- Network performance plugin (bandwidth, latency, jitter) — extends `network_diag`
- Battery/power monitoring plugin — new plugin, OS APIs available
- SAML 2.0 SSO — extends existing OIDC
- ServiceNow/ITSM connector — already on roadmap (Phase 9.5)

**Medium-effort, significant value:**
- App crash/hang detection via OS crash dump monitoring
- Failed logon tracking (Windows Security Event Log correlation)
- License harvesting via app usage tracking
- Driver inventory plugin
- Visual workflow builder (would require significant frontend work)

**Large-effort or architectural changes:**
- Mobile agent (iOS/Android) — new codebase
- VDI/Citrix/VMware monitoring — requires vendor API integrations
- AI/ML predictive analytics engine — new subsystem
- Remote desktop capability — significant new feature
- End-user experience scoring — requires client-side UI instrumentation
- Sentiment analysis — requires NLP/survey infrastructure

### Realistic positioning

For an RFP like this, Yuzu could credibly respond to roughly **40-45% of requirements** with full or strong partial coverage, with a roadmap story for another 15-20%. The remaining ~40% represents capabilities that are outside Yuzu's current architectural scope (DEX-specific monitoring, mobile, VDI, AI/ML).

Yuzu's competitive advantage in this space would be its **open-source nature, modern C++23 architecture, plugin extensibility, and strong security/compliance posture** — areas where commercial DEX tools are often weaker.
