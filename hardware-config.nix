{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    initrd = {
      availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "uas" "sd_mod"];
      kernelModules = [];
    };

    kernel.sysctl = {
      "kernel.sysrq" = 1;
    };

    kernelParams = [
      "panic=10" # reboot 10s after panic
      "oops=panic" # treat oops as panic
      "nvme_core.default_ps_max_latency_us=0" # A2000 APST safety; keep until firmware flashed

      # NOTE: idle=nomwait + processor.max_cstate=1 were Zen1 idle-hang workarounds.
      # Removed for the Intel i5-13500 (no such bug); keeping them would throw away
      # the low-power idle we upgraded for.
    ];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/70678974-5cb2-4f31-beaf-900a7dd0f350";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/7E86-5DF9";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  fileSystems."/hot-storage" = {
    device = "/dev/disk/by-uuid/f755be22-9f04-45d2-a7df-98de07cffb9f";
    fsType = "ext4";
  };

  # Bulk cold storage: the two 4TB IronWolf HDDs as a single btrfs pool (8TB, no
  # redundancy; Backblaze restic is the offsite copy). noatime avoids waking the
  # spindles on reads. Formatted with: mkfs.btrfs -L cold -d single -m raid1 sda sdb
  fileSystems."/cold-storage" = {
    device = "/dev/disk/by-label/cold";
    fsType = "btrfs";
    options = ["compress=zstd:1" "noatime"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
