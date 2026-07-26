# Firesprout hardware upgrade — plan & handoff

Date: 2026-07-23. Market: Germany. Prices are geizhals.de "lowest offer" snapshots and move daily. An adversarial review of this list is in progress; findings get appended at the bottom.

## Decision so far

Replace the Ryzen 7 1700 / AB350 board (first-gen Zen idle-hang, no fix) with an **Intel LGA1700 + QuickSync** platform. Reuse the 32 GB DDR4 and all four drives. **Sell the GTX 1080 Ti.** The build is µATX (needed to use all 4 RAM sticks). Locked components are the same across all three options; only the **case + PSU** differ.

**CHOSEN: Option 3 — Cooler Master Silencio S400 + FSP Dagger Pro 650W SFX. The RM650x will be sold along with the other retired parts. Board: keep the Gigabyte B760M DS3H DDR4 — the NIC idle concern turned out to be a software fix, not a board problem (see the idle-trap verdict at the bottom).**

## How much better than the current box

CPU is a ~2x generational jump, but the real wins are transcoding, power, and stability.

| | Ryzen 7 1700 (now) | i5-13500 (new) | Delta |
|---|---|---|---|
| Cores / threads | 8C / 16T (Zen 1, 2017) | 14C / 20T (Raptor Lake) | — |
| PassMark multi-thread | 14,751 | 30,807 | **2.09x** |
| PassMark single-thread | 1,997 | 3,856 | **1.93x** |
| iGPU / transcode | none (software only) | UHD 770 QuickSync | 1-2 streams → 10-20+ |
| Idle at wall (no dGPU) | ~55-65 W (with 1080 Ti, ~70-80 W) | ~15-20 W tuned | **~3-4x lower** |
| Stability | idle hard-hang every 8-12 h | modern, stable | the point |

- **Transcoding:** today (no iGPU) Jellyfin software-transcodes on the CPU: ~1-2 1080p streams before it chokes. QuickSync does 10-20+ at near-zero CPU. Biggest single win.
- **immich ML:** stays hardware-accelerated (1080 Ti CUDA → iGPU OpenVINO), a touch slower per job but drops a 250 W card (and CUDA 13.x drops Pascal anyway).
- **Power:** saving ~55 W continuous ≈ ~480 kWh/yr ≈ **~€170/yr** at ~0.35 €/kWh.

## Locked components (all three options)

| Part | Pick | ~€ | Reuse? |
|---|---|---|---|
| CPU | Intel Core i5-13500, boxed (incl. Laminar RM1 cooler) | 296 | new |
| Board | Gigabyte B760M DS3H DDR4 (µATX, 4 DIMM, 2.5GbE). Alt: MSI PRO B760M-P DDR4 (~€84, 1GbE) | 86 | new |
| RAM | 4x 8 GB DDR4-3200 CL16 | — | ✅ reuse |
| Storage | Kingston A2000 NVMe (boot) + Crucial MX300 SSD (scratch) + 2x IronWolf 4 TB (data) | — | ✅ reuse |
| CPU cooler | in-box Laminar RM1 is enough for a power-limited 65 W chip; optional quiet upgrade below | 0 | included |

**Board / NIC note (corrected after the idle-trap deep dive):** keep the Gigabyte — the NIC idle penalty is a software fix, not a board-selection problem. Two earlier claims were WRONG and are retracted: the MSI 1GbE board does NOT avoid it (current kernels disable L1 ASPM for the whole modern Realtek family, RTL8111H included), and adding an Intel i226 card would likely be *worse* (its igc driver disables the L1.2 substate + has EEE/L0s quirks). Fix ASPM in software instead — full verdict in the last section of this doc.

## The three case + PSU options

### Option 1 — Bigger case, multiple bays (reuse PSU)
- **Case: Cooler Master Silencio S600** (~€75) — sound-dampened, **4x 3.5"**, ~47 L, fits the 160 mm RM650x (tight against the non-removable cage but it goes in; reviewers call it fiddly). Cooler ≤167 mm (NH-U12S fits).
- Roomier/easier-fit alternative: **SilverStone CS382** (~€243, 8x hot-swap bays, fits ATX easily) if you want a real NAS chassis and don't mind the price/size.
- **PSU: reuse RM650x** (€0).
- Best for: most drive-expansion headroom while reusing the PSU. Downside: biggest of the three, and the S600's 160 mm PSU fit is snug.

### Option 2 — HTPC case (reuse PSU)
- **Case: SilverStone Grandia GD10** (~€125) — horizontal AV-component shape, sits on a media shelf like a receiver. µATX, **2x 3.5" + 1x 2.5"**, ships with 3x 120 mm @ 900 RPM (quiet), **cooler ≤138 mm**.
- **PSU-fit caveat (from review):** headline PSU max is 170 mm, but it drops to **160 mm once the side intake fan + floor 2.5" mount are installed** — so the 160 mm RM650x sits at the exact limit and competes with the very 2.5" bay you'd use for the MX300. It works, but you may have to relocate the SSD to the shared 3.5"/2.5" bay. A shorter PSU (SFX) would make this option cleaner if you don't reuse the RM650x.
- Alternatives: GD11 (~€160, 3x 3.5", 146 mm cooler) / GD09 (~€100, 1 rear fan, add fans).
- **PSU: reuse RM650x** (€0).
- Cooler: stock RM1 fits, or **Noctua NH-U9S (125 mm)** for near-silent. NOT the NH-U12S (158 mm, too tall).
- Best for: living-room / next-to-TV placement while reusing the PSU. Downside: ≤138 mm cooler limit, wider footprint (receiver-width), case costs more.

### Option 3 — Smaller cube, new PSU
- **Case: Cooler Master Silencio S400** (~€56, MCS-S400-KN5N-S00 solid steel) — sound-dampened, **4x 3.5"**, ~34 L (smallest of the three). Cooler ≤167 mm.
- **PSU: new FSP Dagger Pro 650W SFX** (~€97). (The 550W version is EOL in Germany — get the 650W.)
  - **Noise (settled by two adversarial reviews):** the FSP is fanless up to ~200 W, so its fan is OFF across this server's entire normal range (15-200 W) — silent ~99% of the time. The "~42 dBA" in reviews is a full-load figure you'll never reach. Solid internals (100% Japanese 105 °C caps, full protections incl. OTP). Warranty ~5 yr. In stock ~€97.
  - **Seasonic Focus SGX 650 (SFX-L) considered and rejected for this build.** It's *also* fanless past your whole load range, so its nicer 120 mm FDB fan is silence you won't hear. Its only real edges (cleaner ripple, 10-yr warranty) don't help at ~200 W, and it carries a documented **coil-whine lottery** (the one noise a fan-off box CAN make — the FSP has no such reports) plus it's a 2018 design gone near-EOL in Germany (single order-only seller ~€128, which undercuts the warranty value). Not worth the ~€31 premium.
  - **Shared caveat:** a 650 W unit wastes ~8-9 W at ~20 W idle (~€25/yr, ~3% load) — unavoidable given S400-forces-SFX + ~200 W peak + quiet; a smaller quality quiet SFX isn't available. Accepted cost of the small case.
  - **Verdict: FSP Dagger Pro 650W.**
- Why a new PSU: the S400 only clears 140 mm of PSU with its HDD cage in; the 160 mm RM650x doesn't fit. An SFX unit (~100 mm) fits with room to spare and comes with its own complete cable set (no hunting for missing RM650x modular cables). Sell the RM650x (~€50) or keep as a spare.
- Best for: smallest box + most bays + fresh cables. Downside: ~€90-100 PSU spend (net ~€40-50 after selling the RM650x).

### Cost summary (new parts, reusing RAM + storage)

| Option | Case | PSU | New spend | Net (sell RM650x where applicable) |
|---|---|---|---|---|
| 1 — S600 | 75 | reuse | ~€457 | ~€457 |
| 2 — Grandia GD10 | 125 | reuse | ~€507 | ~€507 |
| 3 — S400 | 56 | 100 | ~€538 | ~€490 |

(All = CPU 296 + board 86 + case + PSU; optional cooler NH-U9S ~€65 / NH-U12S ~€80 on top.)

### Why FSP Dagger Pro (vs other SFX units)?
For Option 3 you need a small (SFX) PSU. Among quality SFX units in Germany:
- **FSP Dagger Pro 650W (~€100)** — 80+ Gold, semi-fanless (quiet at idle), fully modular, includes the SFX→ATX bracket, well-reviewed. Best price/quality/quiet balance → the pick.
- Seasonic Focus SGX 650 SFX-L (~€138) — quieter (bigger 120 mm fan) but longer (SFX-L) and pricier. Premium quiet choice if you want to spend more.
- Corsair SF750 2024 (~€163) — Platinum, excellent, but overkill wattage and priciest.
- be quiet! SFX Power 3 450W (~€63) — cheapest but only Bronze with an *always-on* fan, worse for a silent 24/7 box.
- Cooler Master V SFX Gold (~€200) — good unit, overpriced right now.
- MSI: doesn't make a widely-stocked quality SFX unit in Germany (their PSUs are ATX), so not a real option here.

PSU wattage note: 550-650 W is more than this ~150-200 W-peak build needs, but it doesn't hurt — no efficiency penalty at low load, smaller quality SFX isn't cheaper, a bigger unit stays fanless/silent longer, and it leaves headroom for a future GPU. Don't size down.

## Selling the old parts (Germany, realistic sold prices)

| Part | Realistic sold € | Suggested asking € |
|---|---|---|
| Ryzen 7 1700 + AB350 Pro4 as a bundle | 75-95 | 109 VB |
| GTX 1080 Ti | 150-180 | 199 VB |
| Corsair RM650x (if Option 3, sold) | 45-60 | 69 VB |
| Corsair Crystal 570X case (missing parts, broken mesh) | 35-45 | 49 VB |

Retiring CPU+board bundle + 1080 Ti ≈ **€225-275** back, roughly half the build.

## Storage & NixOS setup notes (for after you build)

- **Mirror the 2x 4 TB** (btrfs raid1 or ZFS mirror) for the household-NAS data, keep restic → B2 offsite. Add Samba (macOS/NixOS/partner laptop) and/or NFS.
- **Kingston A2000 APST bug:** update firmware to S5Z42109; if NVMe timeouts appear, boot with `nvme_core.default_ps_max_latency_us=0`. Worth ruling out given the freeze history.
- **Low-idle tuning:** enable C8/C10 + S0ix, ASPM L1, SATA ALPM; `powertop --auto-tune`; boot NVMe on PCH lanes. The board's Realtek 2.5GbE may cost a couple of idle watts vs Intel 1GbE.
- **Crucial MX300** is ~10 years old — check SMART, use as scratch, not a sole copy.
- **Jellyfin:** VAAPI/QSV via UHD 770. AV1 decode yes, AV1 encode no (would need Core Ultra / DDR5 — not required).

## Exposing home services to the internet (Vodafone Cable + FritzBox)

Vodafone Cable is usually DS-Lite (public IPv6, shared IPv4 behind CGNAT), so FritzBox port-forwarding won't work for IPv4. Use the existing Hetzner VPS (nix-dock) as the public front door: WireGuard tunnel home→VPS, and the VPS Caddy reverse-proxies `foundry.deraedt.dev` down the tunnel. Public IPv4, TLS you already do, CGNAT bypassed. Lighter options: Tailscale Funnel or Cloudflare Tunnel (fine for Foundry, not for Jellyfin video). Payoff: move Foundry/heavy services off the RAM-starved VPS onto this box and expose via the tunnel.

## Next actions

1. Pick an option (1 / 2 / 3).
2. Address any FAILs/RISKs from the adversarial review below.
3. Sell the 1080 Ti + CPU/board bundle + 570X.
4. On first boot: firmware-update the A2000, set up the mirror, idle-tune, then bring up services.

---

## Adversarial review findings (2026-07-23)

Three reviewers (compatibility/fit, availability/pricing, design/what's-missing) checked this against geizhals. **No outright FAILs — the build is sound.** Actionable items and gotchas:

### Act on these
1. **Idle trap (Realtek NIC + C-states):** a real ~4 W idle penalty, but it's a software-fixable C-state cliff, not a board choice. Keep the Gigabyte and fix ASPM in software. Full verdict in the "Idle-trap deep dive" section at the bottom (it corrects the MSI-board and Intel-i226 suggestions).
2. **CPU value: the i5-14500 tray (~€244) ≈ the i5-13500 boxed (~€296) once you add a cooler**, and it's slightly faster + better stocked (same silicon, +200 MHz, 20 MB L2). If you're buying an aftermarket cooler anyway, the 14500 tray is the marginally better buy; if you'd use the free in-box cooler, the 13500 boxed is fine. (The 14500 *boxed* is €366 — skip it.)
3. **Keep the A2000 as boot/hot storage** (it's a fine ~2020 TLC NVMe; just flash firmware S5Z42109 for the APST bug). A new NVMe (Crucial P3) is NOT needed — it's a QLC sidegrade that changes nothing you'd notice. **Retire the ~10-year Crucial MX300** (past service life, and old SATA SSDs can cap C-states): either bin/sell it, or keep it as throwaway scratch. Only buy a new NVMe if you want >1 TB of fast storage.
4. **Mirror the 2× IronWolf as a ZFS mirror** for the household data (bit-rot detection, snapshots, easy Samba export). You already have restic→B2 for offsite; the mirror adds local redundancy. RAID is not backup — keep the B2 job.
5. **Buy a SATA data-cable 2-pack (~€6)** — the board ships only 2, you have 3 SATA drives. (Cooler paste is included with Noctua; PSUs have enough SATA power; the GD10 includes fans — nothing else missing.)

### Per-option install notes (all fit; ranked easiest → fiddliest)
- **Option 3 (S400)** and **Option 1 (S600)** install cleaner than Option 2 (GD10).
- **Option 2 (GD10) + RM650x** is the tightest: the 160 mm PSU is at the case's exact limit with the side fan + floor 2.5" installed, and it competes with the MX300's 2.5" mount — you may relocate the SSD. Cleaner with a shorter (SFX) PSU.
- **Option 1 (S600):** RM650x fits (180 mm limit) but the fixed HDD cage + modular cables make routing fiddly.
- **Option 3 (S400 + FSP):** the FSP's 24-pin cable is only 500 mm — should reach in a mATX tower, but budget a ~€6 24-pin extension.
- Cooler heights confirmed: GD10 = 138 mm (NH-U9S 125 mm fits, NH-U12S 158 mm does NOT); S400/S600 ≈ 166-167 mm (anything here fits).

### Verified / non-issues
- **CPU↔board:** B760 runs 13th-gen out of the box; the Gigabyte also has Q-Flash Plus (BIOS flashback) as a safety net. No BIOS worry.
- **RAM:** 4× 8 GB fits (board max 128 GB). Your sticks are single-rank (1Rx8), the "good case" for 4-DIMM — expect DDR4-3200, possibly 2933. Run memtest86 before trusting it.
- **SATA/M.2:** 4 SATA + 2 M.2, both M.2 are PCIe-only (no SATA muxing) — the NVMe + all 4 SATA work simultaneously.
- **PSU:** both units supply 24-pin + 8-pin EPS + enough SATA power (RM650x 9×, FSP 5×). 650 W is oversized but harmless (RMx sits near its sweet spot at ~40% load; SFX stays fanless longer).
- **iGPU:** i5-13500 has UHD 770 (QuickSync + display outputs on the board). Jellyfin: use `intel-media-driver` (iHD) + `/dev/dri/renderD128` passthrough, HEVC output (no AV1 encode on this platform — not needed).
- **Prices:** all verified accurate and in stock. FSP Dagger Pro **550W is EOL** in DE → buy the 650W.

### Verified prices (geizhals, 2026-07-23)
i5-13500 boxed €295.78 · i5-14500 tray ~€244 · Gigabyte B760M DS3H DDR4 €86.23 · MSI PRO B760M-P DDR4 €84.11 · Silencio S600 €74.91 · Grandia GD10 €124.85 (GD09 €99.89 / GD11 €159.85) · Silencio S400 €55.86 · FSP Dagger Pro 650W €96.86 · Noctua NH-U9S €67.55 · NH-U12S €77.29.

### Small extras to add to the cart
1 SATA data cable (~€3) — ONLY if you keep the MX300 as a 3rd SATA drive (the board's 2 cables cover the 2 HDDs otherwise; you likely have spares anyway). 24-pin extension (~€6) — don't pre-buy; the FSP's 50 cm cable probably reaches in the S400, so add it only if it turns out short. Optional 3rd external 4-8 TB USB drive (~€100-130) for a local backup in addition to B2. (Do NOT add an Intel i226 NIC — see the idle-trap verdict; it would likely make idle worse. New boot NVMe NOT needed — the A2000 is good enough.)

## Idle-trap deep dive (verdict)

Ran two opposed reviewers (prove vs refute) with primary sources (kernel commits, instrumented measurements). Conclusion: **real, but a software fix, not a hardware-selection problem — and smaller than first stated.**

- **It's a C-state cliff, not NIC power.** Bimodal: ASPM disabled → package stuck at C3 → **~4 W**; ASPM working → package reaches C8/C10 → **~0.4 W** residual. The NIC's own draw is ~1.8 W either way. So the fix is "get L1 ASPM on," which is free.
- **Corrections to earlier advice:** (a) the MSI 1GbE board does NOT dodge this — current `r8169` disables L1 ASPM for the whole modern Realtek family (RTL8111H included), and Realtek NICs share the same lottery; (b) adding an Intel i226 card would likely be *worse* (igc disables the L1.2 substate, EEE/L0s quirks). The only real hardware win is onboard Intel **I219**, and it needs its own cable-attached C-state check — not worth chasing.
- **The fix (software):** enable **L1 only, never L0s** — `echo 1 > /sys/bus/pci/devices/<addr>/link/l1_aspm` (persist via a NixOS udev/systemd unit) or Realtek's out-of-tree `r8125` DKMS driver. **Never `pcie_aspm=force`** (system-wide, documented freeze trigger). Check silicon: `dmesg | grep r8169` → **XID 641 = safe B/BG stepping** (609 = early-A, the risky one).
- **Freeze-history caveat:** the commit that disabled ASPM cites *"full system hangs."* Treat ASPM-on as a **suspect tested in isolation** — enable it alone, watch for link drops/hangs. Stable → recover ~4 W, hit ~15 W. Flaky → leave off, accept ~18-19 W (fine).
- **Also:** a bad old SATA SSD can pin C-states worse than the NIC (a 10-yr Samsung 840 Pro held a box at C3) — another reason to retire the MX300. Verify with `turbostat` (`Pkg%pc8/pc10`) / `powertop` after the build. Kernel commits: `cf2ffdea0839` (v6.5 disable), `3d9b8ac53412` (v6.15 safe-list), `4d01e55b1ac9` (v6.18 dmesg flag).
