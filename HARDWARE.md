# Firesprout — hardware, BIOS & tuning reference

The home server: NixOS, 24/7, quiet, low-ish idle. Runs paperless-ngx (+tika/gotenberg),
immich (photos + ML), Actual Budget, Caddy, and the diagnostics/watchdog stack. This is the
evergreen reference (the old AMD box and the migration steps are history, not documented here).

## Hardware

| Part | Choice | Why |
|---|---|---|
| CPU | **Intel Core i5-13500** (boxed) | 14C/20T, ~2x the old Ryzen 1700; **UHD 770 iGPU / QuickSync** for Jellyfin transcoding + immich ML accel; runs on DDR4. Note the idle quirk in "Idle power" below (a footnote, not a perf issue). |
| Board | **Gigabyte B760M DS3H DDR4** (rev 1.0) | µATX with **4 DIMM slots** (needed to use all 4x8 GB), DDR4 (reuse RAM), 4x SATA, 2.5GbE. |
| RAM | **4x 8 GB DDR4-3200 CL16** (reused) | Runs at **2933** (4 DIMMs = 2 per channel → 2933 is the stable ceiling, not 3200; confirmed by memtest). |
| Boot / hot | **Kingston A2000 1 TB NVMe** | OS root + `/hot-storage`. See the APST note below. |
| Data | **2x Seagate IronWolf 4 TB** (SATA) | Currently single ext4 (`/hot-storage` split); btrfs pool exists on both disks, unmounted (deferred mirror). |
| Scratch | Crucial MX300 1 TB SATA (~2016) | Old; scratch only, not for anything irreplaceable. |
| Case | **Cooler Master Silencio S400** | Quiet, sound-dampened µATX. |
| PSU | **FSP Dagger Pro 650W SFX** (Gold) | The S400's HDD cage only clears ~140 mm; the reused 160 mm Corsair RM650x didn't fit, so a short SFX unit (with fresh cables) went in. |
| NIC | onboard **Realtek RTL8125 2.5GbE** | See the ASPM decision in "Idle power". |

Sold/retired: GTX 1080 Ti (QuickSync replaces it), Ryzen 1700 + AB350 board, Corsair RM650x, Corsair Crystal 570X case.

## BIOS settings (Gigabyte B760M DS3H DDR4, currently F23)

Stability-first. These are the final, verified settings.

| Setting (Gigabyte menu) | Value | Notes |
|---|---|---|
| CSM Support | Disabled | UEFI/GPT install. |
| Secure Boot | Disabled | stock NixOS GRUB is unsigned. |
| Fast Boot | Disabled | keep firmware/USB access reliable. |
| AC BACK (Platform Power) | Always On | headless box auto-recovers after outage. |
| ErP | Disabled | don't force deep S5 / kill WoL. |
| Above 4G / Re-Size BAR | Disabled | no dGPU. |
| Extreme Memory Profile (X.M.P.) | Profile 1 → settles at **2933** | memtest-clean. |
| C-States Control + CPU Enhanced Halt (C1E) | Enabled | reaches **C3** (the ceiling here — see below). |
| C6/C7/C8/C10 State Support | (any) | **no-op on this CPU** (0xBF uses the ACPI list, not the native table these feed). Don't bother. |
| Package C State Limit | Auto | package is NIC-capped anyway. |
| CPU EIST | Enabled | frequency scaling. |
| Intel Turbo Boost | Auto | (optional Turbo Power Limit = 65 W for less heat/noise). |
| VT-x / VT-d | Enabled | future VMs/Foundry. |
| Native / PCH / DMI ASPM | Enabled | lets the NVMe use L1. **Do NOT force the NIC's ASPM** (see below). |
| SATA Mode | AHCI | not RAID. |
| Smart Fan | Quiet/Silent | 65 W chip runs cool. |

- **BIOS version:** F23. **F24** (latest) is "security/stability" only — optional, not a power lever. (The "F12 latest" you'll see online is the *ATX* `B760 DS3H DDR4` (no "M") — a different board.)
- **Nothing to change**: the box is already in its best achievable BIOS state.

## Idle power & C-states (the honest reality)

Idles around **~19-25 W** (not the ~15 W first hoped). Two independent, structural caps — neither is a fault, and neither affects performance:

1. **CPU model 0xBF has no native `intel_idle` table in *any* Linux kernel** (a 2023 patch was rejected). It falls back to the BIOS ACPI C-state list, which on desktop boards **caps at C3**. So a kernel bump or the C6/C8/C10 BIOS toggles do **nothing** here.
2. **The package is pinned at PC3** because the Realtek NIC's L1 ASPM is deliberately **off** (for stability — the r8169 driver disables it and forcing it can cause link-flaps). Package sleep is where the watts are, so deep core states wouldn't help much anyway.

- **The only real lever (~3-5 W):** re-enable the NIC's L1 ASPM (+ Native ASPM). **Left off on purpose** — a Realtek link-flap drops the headless box off the network and the watchdog *won't* catch it (CPU stays up). Not worth ~5 W.
- **Applied safe lever:** `powerManagement.cpuFreqGovernor = "powersave"` (config). `powertop --auto-tune` is intentionally NOT used (it sets SATA `min_power`, which can drop the spinning HDDs).
- **Verify:** `cat /sys/devices/system/cpu/cpu0/cpuidle/state*/name` (expect `POLL, C1_ACPI, C2_ACPI, C3_ACPI`); `turbostat` package residency sits in PC2/PC3.

## Microcode

CPUID **06-BF-02**, running microcode **0x3e** — this **is the latest** for this signature (the 0x12B/0x12F Raptor Lake Vmin fix belongs to a *different* die, 06-B7, and doesn't apply here). NixOS's `hardware.cpu.intel.updateMicrocode` keeps it current; nothing to do.

## Operational notes (things that bite)

- **NIC name pinned:** the Realtek enumerates differently than the old `enp9s0`, so it's pinned to **`lan0` by MAC** (`configuration.nix`), with the static `192.168.178.210` bound to `lan0`. First boot on any new NIC needs the MAC filled in at the console.
- **Watchdog:** `iTCO_wdt` (Intel PCH TCO) + `systemd` `RuntimeWatchdogSec` — a hard hang self-reboots. Verified armed (no "reboot disabled by hardware"). It does **not** catch a NIC-only link-flap.
- **Service data lives in two places** — remember this for backups/moves:
  - `/hot-storage/*` — immich media (`immich-cold`), paperless (SQLite `db.sqlite3` + media), actual, calibre.
  - **`/var/lib/postgresql`** — the **immich Postgres DB** (albums, faces, ML embeddings). NOT under `/hot-storage`. immich also auto-dumps to `/hot-storage/immich-cold/backups/`.
- **Service uids can drift on a fresh install:** immich is now pinned (`users.users.immich.uid = 998`) after it auto-allocated 998 (old box was 993) and orphaned its media until re-chowned. paperless (315) is already static.
- **Secrets:** agenix secrets are encrypted to the host SSH key (`/etc/ssh/ssh_host_ed25519_key`) — preserve it across reinstalls or re-key. git-agecrypt (`PII.json`) uses the *user* age key at `~/.ssh/git-agecrypt.key`.
- **Kingston A2000 APST:** boot carries `nvme_core.default_ps_max_latency_us=0` for the known Linux hang; keep until firmware S5Z42109 is flashed (the in-kernel quirk also covers it).
- **Caddy TLS (Hetzner DNS-01):** uses the `caddy-dns/hetzner` plugin with `HETZNER_DNS_API_TOKEN` (agenix env file). If certs fail with "Incorrect TXT record found", clean the stale `_acme-challenge.*` TXT records in the Hetzner DNS zone, and confirm the token is a **Hetzner DNS** token (dns.hetzner.com), not a Cloud token.
- **restic → B2:** service files append their paths (e.g. immich appends `mediaDirectory`). Confirm coverage with `restic snapshots`; make sure it also covers paperless + the postgres dump.

## Deferred / possible next steps

- immich ML on the iGPU via OpenVINO (uncomment `intel-compute-runtime` + switch the ML image + pass `/dev/dri`).
- Jellyfin with QuickSync (VAAPI via `/dev/dri/renderD128`, HEVC).
- btrfs/ZFS **mirror** on the 2x IronWolf (the pool exists; destructive to enable — back up first).
