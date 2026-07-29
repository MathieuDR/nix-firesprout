# Self-hosting roadmap & decisions

A decisions record for what to add to **firesprout** (home server) and **nix-dock** (Hetzner
VPS), and why. This is intentionally *not* an implementation guide — the Nix modules, option
names, service placement, secrets, and Caddy wiring are the job of a separate session. This
document captures the *what* and the *why* so that work starts from settled ground.

Profile driving these picks: single-purpose FOSS services in the existing style, privacy-leaning
(KeePassXC, Tuta, anonymize), Linux + Android everywhere (only Apple is a work Mac, browser only),
TTRPG (Foundry), heavy reader, personal finance, Nix-native/declarative.

## Tier 1 — monitoring & alerting (build first)

The services run unattended and today nothing *tells* us when something breaks — a container
crashes, a disk starts declining, or a site goes down silently. Closing that gap is the
highest-value work.

| Decision | Why | Notes / constraints |
|---|---|---|
| **ntfy** for push notifications (not Gotify) | Alerts come from many senders (smartd, systemd, Gatus, restic); ntfy lets each just POST to a topic with no per-source token. Gotify needs a token per sender. UnifiedPush = no Google FCM on Android. | The single alert sink everything else points at. |
| **smartd** for disk health | Most mature SMART tool; it's the actual safety net, not the dashboard. | The IronWolf HDDs spin 24/7 (not parked), so scheduled SMART checks wake nothing. |
| **Scrutiny** for SMART trend history | Consult-on-alert recorder: Backblaze failure-prediction + attribute decline history for IronWolf RMA/replace decisions. | Deliberately *not* a daily dashboard. smartd stays the alert path; Scrutiny is opened when smartd pings. Trend data only exists if it's been collecting all along, hence include it now. |
| **Gatus** for service/status monitoring | Config-as-code fits the declarative flake better than Uptime Kuma. Covers the website + all public/home services. | Black-box endpoint checks only. Can double as a public status page. |
| **systemd `OnFailure` → ntfy** for crash alerts | Containers already run as `podman-*.service` units; catching failed/OOM-killed units is pure systemd, no extra service. | Complements Gatus (Gatus catches "up but wedged"; this catches "process died"). |

**Placement:** the whole stack runs on **firesprout** — ntfy (`ntfy.home`), Gatus (`status.home`),
Scrutiny (`drives.home`), smartd, and systemd `OnFailure`. All monitoring state (Scrutiny's
InfluxDB, Gatus's history) lives on the **NVMe (hot)** — small, DB-backed, and never on the HDDs
Scrutiny watches. Trade-off accepted: monitoring on the box it watches can't self-report firesprout
being *totally* down — fine now the hard-freeze is resolved. Phone push works on the home network
today; reaching it from anywhere waits on the Headscale work below.

Optional in this tier: **cAdvisor** for per-container resource metrics (useful to tune the
existing `MemoryMax` caps on immich/Foundry) — only if graphs are wanted; it's the metrics tier,
not the alert tier.

## Remote access — Headscale (planned, after Tier 1)

Goal: reach the home-only `*.home.deraedt.dev` services — and get monitoring push — from
phone/laptop anywhere. Blocked today by **Vodafone CGNAT** (no inbound IPv4; the FritzBox WireGuard
is effectively IPv6-only, so it's flaky across networks).

**Direction: Headscale** (self-hosted Tailscale control plane) — self-hosted, no third-party IdP,
fits the privacy leaning. It needs a public host (can't live at home behind CGNAT). Preferred on a
*separate* cheap box to keep daily-life access off the projects VPS, but running it on the existing
VPS is acceptable if we'd rather not add a machine. Deferred until after Tier 1.

Rejected: vanilla Tailscale (SaaS + IdP dependency); extending the home WireGuard through the
projects VPS (entangles daily-life traffic with the projects box). Note: with CGNAT, P2P often
falls back to a relay regardless.

## Tier 2 — media & reading (habit-dependent)

The UHD 770 / QuickSync iGPU is configured but idle.

- **Jellyfin** — video, uses the iGPU. Only if video is actually kept around.
- **Audiobookshelf** — audiobooks + podcasts; strong fit for a heavy reader/commuter.
- **Kavita** — ebook/comic reader; closes the gap left by the disabled `calibre-web`.

## Tier 3 — work / homelab ops

- **Forgejo runner + auto-rebuild** — push-to-deploy for the Nix configs (a disabled runner already
  exists on the VPS). Turns manual `nixos-rebuild` into merge-the-PR.
- **Renovate** — auto-PRs bumping flake inputs + container image tags.
- **Syncthing** — sync the nvim markdown notes (and dotfiles) across machines + phone. Chosen over
  a notes *app* because notes already live as plain files in nvim; the only gap is sync.

## Infra hardening (worth doing, not "life-betterment")

- **Authelia** — SSO/2FA in front of the *public VPS* services. Use native **OIDC** for Mealie
  (it supports it); for anything with mobile/API clients, prefer OIDC over a blanket forward-auth
  gate that would break those clients.
- **CrowdSec** (or fail2ban) — intrusion protection on the public VPS.

## Explicitly dropped (and why)

- **Vaultwarden** — already on KeePassXC.
- **AdGuard** — already on the dedicated Raspberry Pi.
- **Memos / Obsidian LiveSync** — personal notes are plain files in nvim; Syncthing covers the real
  gap. (Notion "second brain" is work-only, not personal.)
- **Uptime Kuma** — superseded by Gatus for config-as-code alignment.
- **Nextcloud / SSO-as-lifestyle** — against the clean single-purpose-service style.
