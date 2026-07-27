# Firesprout migration — status & the drive move

## Where we are

- **Platform swap (AMD Ryzen 1700 → Intel i5-13500) is DONE.** The box is assembled in the
  Silencio S400, runs the Intel config, and is reachable at `192.168.178.210`. `kvm-intel` +
  Intel microcode, NVIDIA removed, iGPU/QuickSync in, NIC pinned to `lan0` by MAC — all live.
- **This doc now covers the remaining job: move the OS off the aging Crucial MX300 onto the
  Kingston A2000 NVMe.** The A2000 currently holds an *old, unused* NixOS install (ESP + swap
  + btrfs `nixos`), NOT Windows — safe to wipe. We retire the ~10-year Crucial afterwards.

## Confirmed disk layout (verified with `lsblk -f`)

| Disk | Device | What's on it | Role in this migration |
|---|---|---|---|
| Crucial MX300 (SATA SSD) | `sda` | LIVE NixOS: `sda1` ESP `/boot`, `sda2` `/`, `sda3` `/hot-storage` | **SOURCE + fallback — leave intact** |
| Kingston A2000 (NVMe) | `nvme0n1` | old unused NixOS (ESP + swap + btrfs `nixos`) | **WIPE TARGET — the only disk we touch** |
| 2× IronWolf 4 TB | `sdb`, `sdc` | one btrfs pool `storage` (UUID `b88f…`), unmounted | **do not touch** (data pool, later) |

> **DANGER RULE:** the only disk that gets partitioned/formatted is **`nvme0n1`**. Never
> `sda` (your live OS + data source) or `sdb`/`sdc` (the btrfs pool). Verify the device path
> every time before any `mkfs`/`parted`.

## What you actually preserve (only three things)

1. **Config — nothing to hand-copy.** It's your flake in git. On the new install you `git
   clone` (or it's already checked out on the server). Just **commit/push local changes first**
   (the `README.md` edit) so nothing is stranded.
2. **`/hot-storage` data (~70 GB on `sda3`)** — immich / paperless / actual / calibre. `rsync`
   it to the new `/hot-storage`. The Crucial stays intact through the whole move, so it *is*
   your backup; restic→B2 is the second net.
3. **The host SSH key `/etc/ssh/ssh_host_ed25519_key` (+`.pub`)** — agenix secrets are encrypted
   to it. Copy it onto the new install or your secrets won't decrypt (or re-key, see appendix).

Everything else is rebuilt from the flake.

## The gotcha that bites: filesystem UUIDs change

Your `hardware-config.nix` hardcodes the **Crucial's** UUIDs:

```
/         → b3bf0f1d-106f-4faa-9131-e070a14105f4   (ext4, sda2)
/boot     → 52E6-3F26                              (vfat, sda1)
/hot-storage → 611626bf-dcca-4286-819f-fb714f0e18d0 (ext4, sda3)
```

A fresh `mkfs` on the A2000 produces **new** UUIDs. If you don't update these three, the new
install boots pointing back at the Crucial (or fails). **After formatting the A2000, run
`blkid` and replace all three UUIDs in `hardware-config.nix` before `nixos-install`.** This is
the #1 step people forget. (There's no disko in this repo, so nothing does it for you.)

## Recommended path — install from the running server (no live USB)

Simplest, because the server already evaluates the flake with the git-agecrypt PII decrypted,
and the A2000 is just a spare disk. The Crucial stays booted as source + fallback the whole time.

**0. Prep (from your daily driver).** Commit/push everything. Optionally flash the A2000
firmware now — see the firmware section; the box runs off the Crucial so the A2000 isn't root,
which is exactly when it's safe to flash.

**1. Partition the A2000** — GPT, on the server, **triple-checking the device is `nvme0n1`**:
```sh
lsblk -o NAME,SIZE,MODEL /dev/nvme0n1   # CONFIRM this is the KINGSTON, not sda
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart root ext4 1GiB 200GiB      # OS + nix store
sudo parted /dev/nvme0n1 -- mkpart hotstorage ext4 200GiB 100%
sudo mkfs.fat -F32 -n BOOT /dev/nvme0n1p1
sudo mkfs.ext4 -L nixroot /dev/nvme0n1p2
sudo mkfs.ext4 -L hotstorage /dev/nvme0n1p3
```
(Adjust sizes to taste; 1 TB NVMe easily holds root + `/hot-storage`.)

**2. Grab the new UUIDs and update the config:**
```sh
blkid /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3
```
Edit `hardware-config.nix` → replace the three `fileSystems.*` UUIDs with these. `git add
hardware-config.nix` (flakes only see committed/staged files).

**3. Mount the new target:**
```sh
sudo mount /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/boot /mnt/hot-storage
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo mount /dev/nvme0n1p3 /mnt/hot-storage
```

**4. Install** (from the repo dir on the server; GRUB `efiInstallAsRemovable=true` makes the
A2000's ESP bootable even with no NVRAM entry):
```sh
sudo nixos-install --root /mnt --flake .#firesprout
```

**5. Preserve the host key** (overwrite the freshly-generated one so agenix keeps working):
```sh
sudo cp -a /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub /mnt/etc/ssh/
```

**6. Copy `/hot-storage` data** (both disks are in the box, so local rsync is fastest):
```sh
sudo rsync -aHAX --info=progress2 /hot-storage/ /mnt/hot-storage/
```

**7. Reboot and switch boot order.** In BIOS set the A2000 first. After boot, confirm you're
on the NVMe, not the Crucial:
```sh
findmnt /            # SOURCE should be /dev/nvme0n1p2, not sda2
```

**8. Verify:** `ssh root@192.168.178.210`, `systemctl --failed`, `pics.`/`docs.`/`actual.`
load, `/hot-storage` data intact, `ls /dev/dri` + `vainfo` (iHD), and secrets decrypt (host
key preserved).

**9. Only then retire the Crucial** — wipe it, keep it as scratch, or pull it. Nothing
references it once the A2000 is booting.

## Alternative — live USB (your original idea)

Works, but more moving parts, so only if you prefer a clean room where nothing runs off either
OS disk:
- Boot the NixOS minimal ISO on the box; enable sshd + set a root password in the live env.
- **You'll hit the git-agecrypt wall:** the flake reads `secrets/PII.json`, which is encrypted;
  the bare live env can't decrypt it. So either run `nixos-anywhere`/`nixos-install` **building
  from your daily driver** (it has your age key), or copy the decrypted `PII.json` into the live
  env. This friction is exactly why the from-server path above is simpler.
- Then the same partition → new-UUIDs → install → copy host key → copy data steps.

Your 5-step sketch, corrected: (1) live USB ✔ (2) boot it ✔ (3) "reinstall" = **manual partition
+ update UUIDs + `nixos-install`** — not an automatic `just wipe`, since there's no disko in
the repo (4) `just wipe`/`nixos-anywhere` needs a disko config or a pre-partitioned target, and
it needs your keys — so build from the daily driver; "to temp" is just the live env's DHCP IP
(5) copy files ✔ — local rsync from the Crucial is easiest since both disks are in the box.

## A2000 firmware (APST bug) — flash it while you're in here

Old A2000 firmware has an APST power-state bug (NVMe timeouts/hangs). You carry the kernel
mitigation `nvme_core.default_ps_max_latency_us=0`, so this is belt-and-braces — but since the
A2000 is about to become your boot drive, now's the ideal moment (it's not the running root, so
it's safe to flash from the server, a live USB, or another PC). A flash updates the controller,
not the data.
```sh
sudo nvme list                                  # find the A2000 → /dev/nvme0n1
sudo nvme fw-download /dev/nvme0n1 --fw=S5Z42109.bin
sudo nvme fw-commit  /dev/nvme0n1 -s 1 -a 1     # verify slot/action against Kingston's notes
# power-cycle
```
Windows alternative: Kingston SSD Manager. Verify current firmware/filename on Kingston's site;
have backups (small brick risk). Details + Linux `.bin` source in `hardware-upgrade-plan.md`.

## Reconcile hardware config (belt-and-braces)

After the A2000 is up, confirm the auto-detected hardware matches what you hand-wrote — doubly
relevant now that the UUIDs *and* the boot disk changed:
```sh
sudo nixos-generate-config --show-hardware-config   # prints to stdout, writes nothing
```
Diff against `hardware-config.nix` and reconcile `boot.initrd.availableKernelModules` and the
`fileSystems` UUIDs by hand. Don't let it overwrite the file (it targets
`/etc/nixos/hardware-configuration.nix`, wrong for this flake, and your file has hand edits:
Intel microcode, the `nvme_core...=0` param). Rebuild if you change anything.

## Deferred follow-ups (each a separate, deliberate step)

- **IronWolf btrfs pool (`sdb`+`sdc`, label `storage`).** It already exists — check the profile
  first: `sudo mount /dev/sdb /mnt2 && sudo btrfs filesystem usage /mnt2`. If `Data` is
  **RAID1**, your mirror is already built (just uncomment `/storage`, or move `/hot-storage`
  onto it). If it's `single`/`RAID0`, rebuilding it as RAID1 is DESTRUCTIVE — back up to
  B2/external first. RAID isn't backup; keep the restic→B2 job.
- **Jellyfin** with QuickSync (VAAPI/QSV via `/dev/dri/renderD128`, HEVC out).
- **immich ML on the iGPU** (OpenVINO): uncomment `intel-compute-runtime` in
  `configuration.nix`, switch immich to the openvino ML image, pass `/dev/dri`.
- **Idle tuning:** Realtek L1 ASPM in isolation (never `pcie_aspm=force`), `powertop
  --auto-tune`. See the idle-trap section of `hardware-upgrade-plan.md`.

## Appendix — re-keying (only if you did NOT preserve the host key)

Skip if you copied `/etc/ssh/ssh_host_ed25519_key*` in Step 5. Otherwise the fresh install has a
new host key and agenix secrets won't decrypt:
1. Get the new host key: `ssh root@192.168.178.210 'cat /etc/ssh/ssh_host_ed25519_key.pub'`.
2. In `secrets/secrets.nix`, replace the old firesprout host public key with the new one.
3. In the devshell, rekey: `agenix -r` (re-encrypts all `*.age`). Commit the results.
4. git-agecrypt PII (`PII.json`) is encrypted to your **user** age keys, not the host —
   unaffected, nothing to do.
5. Redeploy; secrets now decrypt on the new host.
