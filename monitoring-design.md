# Design: Tier-1 monitoring & alerting (firesprout)

Status: design agreed 2026-07-29, ready for an implementation plan. Companion to
`selfhosting-roadmap.md` (Tier 1). This is the *what/why/how*, not the final Nix.

## Context

The services run unattended and nothing currently *tells* us when something breaks — a container
crashes, a disk starts declining, or a site goes down silently. This closes that gap. The whole
stack runs **on firesprout** (hobby box; an external watcher on the VPS was declined — accepted
trade-off: it can't self-report firesprout being *totally* down, which matters little now the old
hard-freeze is resolved). Alerts reach the phone on the home network today; from-anywhere is
unlocked later by the Headscale work (roadmap). Everything is kept lightweight and cullable.

## Components (all on firesprout)

| Component | Where | Job | Alerts via |
|---|---|---|---|
| **ntfy** | `ntfy.home` | The single alert sink + phone push | — (it *is* the sink) |
| **smartd** | — | Scheduled SMART self-tests + early/granular disk alerts | `-M exec` script → ntfy |
| **smart-history timer** | — | Weekly `smartctl --json -x` → append `.jsonl` (attrs + self-test log) | — (data only) |
| **Beszel** (hub+agent) | `metrics.home` | Box health (CPU temp, sensors, RAM, load, disk, net) + per-container stats + SMART snapshot; host-level threshold alerts | native ntfy (Shoutrrr) |
| **Gatus** | `status.home` | Endpoint up/down for every service + website + Foundry | native ntfy provider |
| **systemd `OnFailure`** | — | Per-container/service crash / OOM / restart-loop alerts | template unit → ntfy |

Dropped/deferred: **Scrutiny** (SMART failure-prediction + attribute-history dashboard — fleet-scale
value, overkill for 2 drives; smartd alerts + Beszel snapshot + the `.jsonl` cover the hobby case).
**Netdata** (not needed; the only thing it'd add over Beszel is SMART *attribute-history graphs* — if
ever wanted, add Netdata then, don't reintroduce Scrutiny). **cAdvisor**, **Glance overlay** — later.

## Coverage (why each earns its place)

- **systemd `OnFailure`** is the *only* thing that catches a single container dying — Beszel shows a
  failed `podman-*` unit on its dashboard but has no alert for it (upstream issue #1813); Gatus only
  catches services that expose a checkable endpoint. So `OnFailure` stays.
- **Gatus** catches "up but wedged" / endpoint down, and covers the public VPS things from here.
- **Beszel** catches host-level trouble (CPU/mem/disk/temp/load/bandwidth/box-down) and is the box
  telemetry + container-cost meter.
- **smartd** is the deep disk net: it *runs* self-tests (Beszel only reads) and alerts *earlier* and
  more granularly (attribute change, temperature, self-test failure) than Beszel's health-flip.

## Data flow

All senders publish to a topic on the local ntfy; the phone's ntfy app subscribes (home LAN now,
anywhere post-Headscale). Publishers: Gatus (native ntfy), Beszel (native ntfy Shoutrrr URL), smartd
(`-M exec` curl script), `OnFailure` template unit (curl). One publish token authenticates all
senders. Topic: `firesprout` (single topic; revisit splitting alerts/info later).

## Storage (hot/cold)

Every bit of monitoring state lives on the **NVMe (hot)** under `/var/lib/*`, never on the HDDs:
`beszel-hub` data, ntfy cache/db, Gatus history (if enabled), and `/var/lib/smart-history/smart.jsonl`.
Rationale unchanged: small, DB-backed, frequently written; and the disk monitor must not write onto
the disks it watches.

## Component detail

### ntfy (`services.ntfy-sh`)
- `base-url = https://ntfy.home.deraedt.dev`, listen `127.0.0.1:<port>`, Caddy vhost in front
  (LAN/tailnet only; `*.home` never resolves publicly).
- Auth: `auth-default-access = deny-all`; a **publish token** (agenix) that senders use; a user login
  for the phone. Future-proofs Headscale exposure and keeps alerts off open-LAN.

### smartd (`services.smartd`)
- Devices: `/dev/sda`, `/dev/sdb`, `/dev/nvme0`.
- Directives: health (`-H`), failure/usage attribute change (`-f`, `-C 197`, `-U 198`), temperature
  (`-W diff,info,crit`), and a self-test schedule (`-s (S/../.././02|L/../01/./03)` — short daily-ish,
  long monthly; final cadence tuned in the plan).
- Notification: `-M exec <ntfy-notify script>` (+ `-M test` on start to prove the path). Script curls
  the ntfy topic with the publish token; must be robust (timeout + one retry).

### smart-history timer
- `systemd.timers` weekly (daily is also fine — a few KB/run). Script loops the devices, runs
  `smartctl --json -x /dev/<d>`, wraps each with `jq -c '{ts, device, smart:.}'`, appends one line per
  drive to `/var/lib/smart-history/smart.jsonl`. `-x` includes the attribute table, error log, and
  **self-test log** → machine-readable trend data (build a graph on demand if ever wanted). Retain
  indefinitely.

### Beszel (`services.beszel.hub` + `services.beszel.agent`, native in 25.11)
- Hub: `127.0.0.1:8090`, `dataDir=/var/lib/beszel-hub`, Caddy vhost `metrics.home`. Set `APP_URL` so
  notification links are correct.
- Agent: **WebSocket mode** (`DISABLE_SSH=true`); `KEY`/`TOKEN` via `environmentFile` (agenix). Hub +
  agent on the same host.
- SMART: `agent.smartmon.enable = true`, `deviceAllow = ["/dev/nvme0" "/dev/sda" "/dev/sdb"]`.
- **Container stats (podman):** the agent (DynamicUser, hardened) needs read access to the **rootful**
  podman socket (`/run/podman/podman.sock`) via `DOCKER_HOST` + socket group/ACL; enable
  `podman.socket`. Gate systemd view with `SERVICE_PATTERNS="podman-*,beszel*"`. *(Plan must solve the
  DynamicUser↔rootful-socket access cleanly; fallback: skip container stats if it gets ugly.)*
- Notifications: ntfy Shoutrrr URL (`ntfy://:<token>@ntfy.home.deraedt.dev/firesprout`), per-user;
  enable Status + CPU/Memory/Disk/Temperature/Load alerts per-system with sane thresholds.
- Note: Beszel's SMART alert is automatic (fires on transition to failure) — redundant with smartd,
  which is fine.

### Gatus (`services.gatus`)
- Caddy vhost `status.home`. `alerting.ntfy` configured once; each endpoint gets `alerts = [{ type =
  "ntfy"; }]`.
- **Endpoints as a flat, one-attrset-per-line list grouped by host so any can be deleted to cull:**
  - Home (firesprout): `pics.home` (immich), `docs.home` (paperless), `actual.home`, `recipes.home`
    (mealie), `ntfy.home`, `metrics.home` (Beszel). (`status.home` self-check optional.)
  - Public: `mathieu.deraedt.dev` (website), `drakkenheim.deraedt.dev` (Foundry).
  - VPS public (enumerate exact vhosts from `nix-dock` at plan time; known subdomains:
    `glance`, `garden`, `invest`, `feed`, `readlater`, `l`, `insights`, `books`, `kenny`, `www`,
    `ddb-proxy`). Each a standalone block; cull freely.

### systemd `OnFailure` → ntfy
- One reusable template `systemd.services."ntfy-failure@"` (oneshot): curls the ntfy topic with the
  failed unit name (`%i`) + `journalctl -u %i -n 20` tail, using the publish token.
- Attach `onFailure = ["ntfy-failure@%n.service"]` to the `podman-*` units and key native services
  (immich-server, immich-machine-learning, paperless-*, mealie, actual, caddy, restic).

## Secrets (agenix)
- `ntfy publish token`, `beszel KEY`, `beszel TOKEN`. New `.age` files + `secrets.nix` entries; wire
  via `environmentFile`/token files (never inline in the store).

## Resource budget + measurement (explicit ask)
- Cap each: `MemoryMax`/`MemoryHigh` on ntfy (~64M), Gatus (~64M), beszel-hub (~128M), beszel-agent
  (~64M); smartd negligible.
- Measure after deploy: Beszel's own per-service/per-container stats + `systemctl show -p MemoryCurrent`.
  Report actuals back (Beszel is the meter for its own stack).

**Measured footprint (2026-07-29):** ntfy 13M · beszel-hub 9.1M · gatus 9.5M · smartd 1.7M ≈ **~33 MB**
total RAM (beszel-agent ~10M once enabled; smart-history is a weekly oneshot). Well under the caps;
no adjustment needed.

## Error handling / edge cases
- ntfy on the same box as everything → if firesprout is fully down, nothing can alert (accepted;
  freeze resolved). Optional later: Beszel **heartbeat** → an external uptime service as a dead-man's
  switch.
- smart-history / Beszel ordering: `After=` the relevant mounts, not `Requires`, so a mount hiccup
  can't block them.
- Beszel agent SMART needs `CAP_SYS_RAWIO`+`CAP_SYS_ADMIN`; the module handles this via `smartmon`.
- Publish-token/auth failures surface as no-alerts — the `-M test` + a manual curl in verification
  guard against that.

## Verification (end to end)
1. **ntfy:** `curl -H "Authorization: Bearer <token>" -d test https://ntfy.home.deraedt.dev/firesprout`
   → phone receives.
2. **smartd:** starts and sends its `-M test` ping; `smartctl -t short /dev/sda` completes.
3. **smart-history:** trigger the timer once; `jq . /var/lib/smart-history/smart.jsonl` shows attrs +
   self-test log per drive.
4. **Beszel:** dashboard shows CPU temp / RAM / disks / podman containers; trip a low temp/CPU
   threshold to fire a test ntfy; stop the agent → Status alert.
5. **Gatus:** `status.home` lists all endpoints green; stop one service → its ntfy alert fires.
6. **OnFailure:** `systemctl kill -s SIGKILL podman-mealie` (low-stakes) → crash alert on the phone.
7. **Cost:** record `MemoryCurrent` for each unit + Beszel's container view; confirm under caps.

## Out of scope
Scrutiny, Netdata, cAdvisor, the Glance overlay, and Headscale/remote-access (its own roadmap item).
