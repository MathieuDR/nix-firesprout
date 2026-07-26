# Firesprout → Intel platform migration (step by step)

Moving from the Ryzen 7 1700 / AB350 (Zen1 idle-hang) to the new Intel box:
i5-13500 · Gigabyte B760M DS3H DDR4 · Silencio S400 · FSP Dagger Pro 650W SFX.
Reusing the 32 GB DDR4 and all four drives.

## TL;DR — data & keys (read this first)

- **Do you need to format? No** — not for the platform swap. The same drives move
  into the new box; NixOS boots off the A2000 and mounts `/hot-storage` (all your
  service data: immich, paperless, actual, calibre) by UUID, unchanged. Nothing is
  reformatted, nothing is lost.
- **Do you need new keys? No** — keeping the A2000 install preserves `/etc/ssh` (the
  host key) and the agenix identity, so secrets keep decrypting. New keys are only
  needed if you do a *fresh reinstall* (see the appendix).
- **Formatting only happens for two optional, deferred things:** the ZFS mirror on the
  IronWolfs (back up first) and a fresh OS reinstall (not required).

## What this branch already changed (config)

- `hardware-config.nix`: `kvm-amd` → `kvm-intel`, Intel microcode, dropped the Zen1
  `idle=nomwait` + `processor.max_cstate=1` params (kept `nvme_core...=0` for the A2000).
- `configuration.nix`: NIC pinned to a stable `lan0` **by MAC** (placeholder to fill),
  static `192.168.178.210` bound to `lan0`; Intel iGPU (`hardware.graphics` + QuickSync).
- `services/immich.nix`: removed all NVIDIA config; ML falls back to CPU for now.
- `services/diagnostics.nix`: netconsole now streams from `lan0`; `hung_task_panic`
  turned **off** (a ZFS scrub can block a task >60s on a healthy box); black-box +
  netconsole + watchdog kept as burn-in insurance.

**The one thing left to fill:** the new NIC's MAC in `configuration.nix`
(`systemd.network.links."10-lan0".matchConfig.MACAddress`). Get it in Step 3.

## Step 1 — Assemble

Into the S400: board, CPU + cooler, all 4 DDR4 sticks, A2000 (M.2), MX300 (SATA),
2× IronWolf (SATA), FSP SFX PSU. **Attach a monitor + keyboard** — you need console for
first boot because the NIC changes name and the old static-IP config won't apply.

## Step 2 — First boot (BIOS + console)

- Enter BIOS. Confirm: **32 GB / all 4 DIMMs** seen, all drives detected, boot device =
  the A2000's EFI partition. Leave RAM at stock first (the sticks ran at 3200 before;
  enable XMP/DOCP later if memtest is clean). Set a sane fan curve.
- Boot. The existing generation loads fine — `kvm-amd` just doesn't load and there's no
  NVIDIA card (both harmless). You land at a text console.
- Log in as `thieu` (or `root`).

## Step 3 — Temporary network + grab the MAC

```sh
ip -o link                       # note the ethernet iface name AND its link/ether MAC
sudo ip link set <iface> up
sudo dhcpcd -4 <iface>           # or: sudo systemctl start dhcpcd
ip -4 addr show <iface>          # note the temporary IP it got
ping -c2 1.1.1.1                 # confirm internet
```

Write down the **MAC** and the **temp IP**.

## Step 4 — Finalize config + deploy (from your Mac)

1. Put the MAC into `configuration.nix` → `matchConfig.MACAddress = "aa:bb:...";`.
2. Deploy to the temp IP, building on the box (your Mac is aarch64-darwin, no Linux builder):
   ```sh
   nix run nixpkgs#nixos-rebuild -- switch \
     --flake .#firesprout \
     --target-host root@<tempIP> --build-host root@<tempIP>
   ```
3. This activates the Intel config: the NIC is renamed to `lan0` and `192.168.178.210`
   is applied. The box moves to `.210`.
4. Reboot and confirm a clean boot on the real address: `ssh root@192.168.178.210`.

## Step 5 — Reconcile the hardware config (belt-and-braces)

Not strictly required to boot: the existing `hardware-config.nix` already carries the
boot-critical bits — filesystems are by UUID (same disks, unchanged), and the initrd has
`nvme` + `ahci`, which aren't AMD-specific. They're the same drivers this system already
boots and mounts SATA with, which is *why* it comes up on the Intel board at all
(AMD and Intel are both x86-64; the kernel auto-loads the new chipset's drivers at runtime).
But that `availableKernelModules` list was generated on the AB350, so confirm it matches
what the B760M actually detects:

```sh
sudo nixos-generate-config --show-hardware-config   # prints to stdout, writes nothing
```

Diff the output against `hardware-config.nix` and merge anything relevant by hand — mainly
`boot.initrd.availableKernelModules`; sanity-check the filesystem UUIDs match (they will).
Don't let it overwrite the file: plain `nixos-generate-config` targets
`/etc/nixos/hardware-configuration.nix` (wrong path for this flake), and your
`hardware-config.nix` has hand edits (Intel microcode, the A2000 `nvme_core...=0` param).
If you changed anything, `nixos-rebuild switch` again.

If the box ever *won't* boot because the initrd can't find root (unlikely — `nvme`/`ahci`
are generic), regenerate from the install USB instead: boot the ISO, mount root at `/mnt`,
`sudo nixos-generate-config --root /mnt`, reconcile the modules, `nixos-rebuild boot`.

## Step 6 — Validate

- **RAM:** run **memtest86** (GRUB entry) overnight before trusting the reused DDR4 —
  it's the one component most likely to cause fresh instability.
- **Services:** `systemctl --failed`; check `pics.`/`docs.`/`actual.` URLs. Data on
  `/hot-storage` is untouched.
- **iGPU:** `ls /dev/dri` (expect `renderD128`); `nix-shell -p libva-utils --run vainfo`
  should list the **iHD** driver with H264/HEVC encode+decode entrypoints.
- **Burn-in:** black-box (`/var/lib/blackbox/metrics.log`) and netconsole→hpi keep
  running. (Make sure hpi is on the `diagnostics/netconsole-receiver` branch so it
  listens; the receiver interface didn't change.)

## Step 7 — Deferred follow-ups (each a separate, deliberate step)

- **ZFS mirror on the 2× IronWolf** — DESTRUCTIVE to those disks. Back their data up to
  B2/external first, create the mirror, restore, export via Samba/NFS. RAID isn't backup;
  keep the restic→B2 job.
- **Jellyfin** with QuickSync (VAAPI/QSV via `/dev/dri/renderD128`, HEVC out).
- **immich ML on the iGPU** (OpenVINO): uncomment `intel-compute-runtime` in
  `configuration.nix`, switch immich to the openvino ML image, pass `/dev/dri`.
- **Idle tuning** (optional): Realtek L1 ASPM in isolation (never `pcie_aspm=force`),
  retire the ~10-year MX300, `powertop --auto-tune`. See the idle-trap section of
  `hardware-upgrade-plan.md`.

## A2000 firmware (APST bug) — optional, data-safe

Old A2000 firmware has an APST power-state bug (NVMe timeouts/hangs). You already carry
the kernel mitigation `nvme_core.default_ps_max_latency_us=0`, so this is belt-and-braces.
A firmware flash updates the controller, **not your data** — but there's a small brick
risk, so have backups. Do it from a live USB where the A2000 is **not** the running root
(or on another PC):

```sh
sudo nvme list                                   # find the A2000 → /dev/nvmeX
# download the fixed firmware image (plan notes S5Z42109 — verify current on Kingston's site)
sudo nvme fw-download /dev/nvmeX --fw=firmware.bin
sudo nvme fw-commit  /dev/nvmeX -s 1 -a 1        # verify slot/action against Kingston's notes
# power-cycle
```

Windows alternative: Kingston SSD Manager. Or just skip it — the freeze was the CPU, not
the A2000, and the kernel param already covers you.

## Appendix — fresh reinstall (only if you choose it; NOT required)

Reasons you might: want a clean slate, or move root to a new/bigger NVMe. Otherwise skip.

**WARNING:** reformatting the A2000 wipes the OS. Your service data lives on a *different*
disk (`/hot-storage`), so leave the data disks untouched and they survive (mounted by
UUID). Do not include them in any partition/format step.

Install options:
- `just wipe` (nixos-anywhere) — wipes the *target* and installs the flake. Point it only
  at the A2000; keep the data disks out of the disko/partition scope.
- Manual: boot the NixOS ISO, partition the A2000 (GPT: ~512 MB ESP vfat + rest ext4 root),
  `mount`, then `nixos-install --flake .#firesprout`.

**Re-keying (required after a fresh install — the host SSH key changes):**
1. Get the new host key: `ssh root@<box> 'cat /etc/ssh/ssh_host_ed25519_key.pub'`
   (or `ssh-keyscan <ip>`).
2. In `secrets/secrets.nix`, replace the old firesprout host public key with the new one.
3. In the devshell, rekey every agenix secret: `agenix -r` (re-encrypts all `*.age` to the
   recipients in `secrets.nix`). Commit the re-encrypted files.
4. git-agecrypt PII (`PII.json`, `.envrc_pii`) is encrypted to your **user** age keys, not
   the host — unaffected, nothing to do.
5. Redeploy; secrets now decrypt on the new host.
