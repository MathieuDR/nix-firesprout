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
      "nvme_core.default_ps_max_latency_us=0"

      "idle=nomwait"
      "processor.max_cstate=1"
    ];
    kernelModules = ["kvm-amd"];
    extraModulePackages = [];
  };

  # boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "uas" "sd_mod"];
  # boot.initrd.kernelModules = [];
  # boot.kernelModules = ["kvm-amd" "nvme_core.default_ps_max_latency_us=0"];
  # boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/b3bf0f1d-106f-4faa-9131-e070a14105f4";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/52E6-3F26";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  fileSystems."/hot-storage" = {
    device = "/dev/disk/by-uuid/611626bf-dcca-4286-819f-fb714f0e18d0";
    fsType = "ext4";
  };

  # fileSystems."/storage" = {
  #   device = "/dev/disk/by-uuid/b88f560b-9fd0-45b1-a49f-5e0979cb091c";
  #   fsType = "btrfs";
  #   options = ["compress=zstd" "noatime"];
  # };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
