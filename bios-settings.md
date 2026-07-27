# Firesprout BIOS + firmware settings — Gigabyte B760M DS3H DDR4 + i5-13500

Date: 2026-07-23. Machine: quiet 24/7 NixOS home server (S400, reused DDR4-3200, A2000 boot).

**Guiding principle: stability first.** This box replaces one that hard-froze, so anything that
trades stability for a few watts is discouraged. Legend: ✅ recommended · ⚠️ conditional · 🚫 discouraged.
Gigabyte menu paths are noted; they shift slightly between BIOS revisions.

## Order of operations (do it in this sequence)

1. **Flash the latest stable BIOS, load Optimized Defaults** (microcode — see step 0). Then set the rest.
2. **AC BACK = Always On, ErP = Disabled** (auto-recovery after power loss).
3. **Set up a watchdog in NixOS** so a future hard-hang self-reboots instead of sitting frozen.
4. **Memory: XMP Profile 1, then a full overnight memtest86.** Drop to 2933/2133 on any error.
5. **C-States = Enabled, C1E = Enabled, Package C State Limit = Auto** (do NOT force C10).
6. **Platform Power Management = Enabled; PCH/DMI ASPM = Enabled; Native ASPM = Enabled.** NVMe gets L1; OS keeps the NIC's ASPM off. Never `pcie_aspm=force`.
7. CSM off, Secure Boot off, Fast Boot off, Above 4G/ReBar off, AHCI, EIST on, Turbo Auto (optional 65 W cap), VT-x/VT-d on, quiet fan.
8. Accept a few extra idle watts from NIC-ASPM-off. It's the price of not freezing.

## Step 0 — BIOS / microcode update (the #1 stability item)

🚨 **Flash to the latest stable BIOS before anything else.** Intel's Raptor Lake Vmin-Shift
instability is fixed by microcode **0x12B** (final fix) + **0x12F** (edge-case refinement), which ship
**only via BIOS**. On this board: 0x12B landed in **vF19**, 0x12F in **vF21/vF21c** (later: vF22 VT-d
default, vF23 Secure Boot). ✅ Recommended.

- Honest nuance: the **i5-13500 is a 65 W part and was NOT among the degraded SKUs** (that was high-voltage
  i7/i9 K chips). So risk to *this* chip is low — but the fix is free and Intel recommends it for all
  13th/14th-gen desktop parts, and a stability-first box should be on 0x12F regardless.
- Verify from Linux after: `grep microcode /proc/cpuinfo` / `journalctl -k | grep microcode`.
- The BIOS/FIT microcode is authoritative for the SVID/eTVB fix — don't rely on OS `intel-ucode`
  late-loading alone (you can add `hardware.cpu.intel.updateMicrocode` as defence-in-depth).

## Boot / firmware (Boot menu)

| Setting | Set to | | Why |
|---|---|---|---|
| CSM Support | **Disabled** | ✅ | UEFI/GPT install (already booting this way). |
| Secure Boot | **Disabled** | ✅ | Stock NixOS GRUB is unsigned. (Re-check after a BIOS flash — vF23 may nudge it on.) |
| Fast Boot | **Disabled** | ✅ | On a rarely-rebooted server, skipping device init hurts USB/recovery access when you *do* need firmware. Serviceability > a few seconds. |
| Above 4G Decoding / Re-Size BAR | **Disabled** | ✅ | No dGPU → no benefit; ReBar without a supporting GPU is pointless and occasionally quirky. |

## Platform Power (Settings > Platform Power)

| Setting | Set to | | Why |
|---|---|---|---|
| AC BACK | **Always On** | ✅ | Headless box must auto-recover after an outage. (Values: Always Off / Always On / Memory.) |
| ErP | **Disabled** | ✅ | ErP=Enabled forces deep S5 and disables Resume-by-Alarm/WoL; unwanted on an auto-recovering server and doesn't help *running* idle power. |
| Platform Power Management (master ASPM) | **Enabled** | ✅ | Enables PCIe link power management platform-wide. |
| PCH ASPM / DMI ASPM / PEG ASPM | **Enabled / Auto** | ✅ | The A2000 hangs off PCH/M.2 lanes → PCH ASPM gives it L1 idle savings. |
| Native ASPM (ForceOSC handoff) | **Enabled** | ✅ | Hands ASPM policy to the OS so Linux governs per-device (and correctly keeps the NIC's ASPM off). "Auto"/Disabled lets firmware fight the driver. |

## Memory (Tweaker menu)

| Setting | Set to | | Why |
|---|---|---|---|
| Extreme Memory Profile (X.M.P.) | **Profile 1** | ⚠️ | Restores DDR4-3200 (you're at JEDEC 2133). **Run `memtest86` for a full overnight multi-pass FIRST.** 4 single-rank DIMMs on a budget B760 often won't hold full 3200 — any errors → **2933**, else 2133. Stability >> the throughput delta (irrelevant for this workload). |
| Manual timings / voltage OC | — | 🚫 | Instability risk; XMP is enough. |

## CPU power / C-states (Settings > Platform Power / CPU — "C-States Control")

| Setting (correct Gigabyte name) | Set to | | Why |
|---|---|---|---|
| C-States Control | **Enabled** | ✅ | Master C-state enable. Modern Intel C-states are mature/stable — not the Zen1 idle-hang situation. Biggest idle lever. (There is no "Global C-state control" on Gigabyte — that's an AMD/ASUS term.) |
| CPU Enhanced Halt (C1E) | **Enabled** | ✅ | Standard core idle. |
| Package C State Limit | **Auto** (NOT C10 / "No Limit") | ⚠️ | Auto lets the platform negotiate. **Don't force C10** — deep package C-states + PCIe ASPM is the historical Linux idle-hang combo, and you're stability-first. If an idle hang ever appears, cap at **C6** first. |
| CPU EIST Function | **Enabled** | ✅ | Frequency scaling. (SpeedShift/HWP is OS-driven via `intel_pstate` — no BIOS toggle.) |
| Intel Turbo Boost | **Auto** | ✅ | Optional: Tweaker > **Turbo Power Limits** → set Power Limit TDP = 65 W for less heat/noise. Helps thermals; harmless. |
| VT-x / VT-d ("...for Directed I/O", Settings > Miscellaneous) | **Enabled** | ✅ | Harmless; useful for future VMs/Foundry. |
| Low Power S0 Idle / Modern Standby (S0ix) | leave default | — | Predominantly an **ASRock** option; **likely absent on this Gigabyte board.** If it doesn't appear, there's nothing to do — don't chase hidden-menu hacks to disable something that isn't hurting you. |

## PCIe ASPM — THE TRAP

| Setting | Set to | | Why |
|---|---|---|---|
| Force ASPM on the Realtek 2.5GbE NIC (BIOS force, kernel `pcie_aspm=force`, udev L1 override, or the out-of-tree `r8125` driver) | **NO — leave NIC ASPM off** | 🚫🚫 | The `r8169` driver disables L1 ASPM on the RTL8125 because forcing it causes device-drops and **full system hangs** — the exact idle-freeze class you migrated away from. Stability-first → leave it off. |

Cost of leaving it off: **a few watts (~1.5-3 W at the NIC, possibly a bit more at the package**, since a
non-ASPM link can hold the package out of deep PC-states). The earlier "~4 W / down to 15-18 W" figure was
optimistic — treat it as a small penalty, not worth the hang risk. **Never `pcie_aspm=force`** (that would
force the NIC too).

## Storage / fans

| Setting | Set to | | Why |
|---|---|---|---|
| SATA Mode (Settings > IO Ports) | **AHCI** (not RAID) | ✅ | Already correct. |
| SATA link power (OS-side) | **`med_power_with_dipm`** at most | ⚠️ | Not a BIOS toggle. Avoid `min_power` — it has dropped drives on some SATA controllers; you have 2 spinning HDDs, so stay conservative. |
| Smart Fan / fan curve | **Quiet / Silent** preset | ✅ | 65 W chip runs cool; keep it near-silent by the TV. Don't set the CPU-fan minimum so low it stops under summer idle; enable a fan-fail warning. |

## NixOS-side (not BIOS) — do these too

- **Watchdog (the single best insurance against another freeze):** enable the Intel TCO watchdog so a hard
  hang auto-reboots instead of sitting frozen like the old box:
  `boot.kernelModules = [ "iTCO_wdt" ];` + `systemd.watchdog.runtimeTime = "20s"` (and `rebootTime`). ✅ Strongly recommended.
- **`powertop --auto-tune`** as a systemd oneshot — captures the safe ASPM/ALPM idle wins **without**
  forcing the NIC.
- Microcode defence-in-depth: `hardware.cpu.intel.updateMicrocode = true` (BIOS is still authoritative).

## Idle-power expectation (a range, not a promise)

~19-24 W idle for i5-13500 + A2000 + 2 HDDs, but **~6-10 W of that is the two spinning HDDs** — depends
heavily on whether they spin down. Don't chase the last couple of watts by forcing the NIC. Stability wins.

## Adversarial review — corrections applied (2026-07-23)

This doc was revised after an adversarial verification pass against the DS3H manual + Gigabyte docs:
- **Added Step 0 (BIOS/microcode 0x12F)** — the biggest stability item, was missing.
- **Added a NixOS watchdog** — auto-reboot on hard hang; the best guard against a freeze repeat.
- Fixed setting names to Gigabyte terminology ("C-States Control", "CPU EIST Function", "AC BACK",
  "Platform Power Management", "Native ASPM", "Turbo Power Limits", VT-d path).
- **C-state: Package C State Limit = Auto, not C10** — forcing C10 + ASPM is the classic Linux idle-hang combo.
- **S0ix is likely absent** on Gigabyte (ASRock feature) — don't hunt for it.
- Added ErP=Disabled, Fast Boot=Disabled, Above 4G/ReBar=Disabled, and the SATA ALPM `med_power_with_dipm` caution.
- Softened the NIC-ASPM idle penalty from "~4 W" to "a few watts."

Sources: Gigabyte 600-series BIOS manual; B760M DS3H DDR4 install guide + support/BIOS pages;
flashmyboard BIOS/microcode revision tracker (0x12B→vF19, 0x12F→vF21c); Intel Raptor Lake instability
root-cause + 0x12B/0x12F confirmations; r8169/RTL8125 ASPM system-hang reports.
