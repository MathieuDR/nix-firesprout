{
  self,
  pkgs,
  lib,
  config,
  ...
}: let
  mediaDirectory = "/hot-storage/immich-cold";
in {
  # Overlay to enable CUDA for onnxruntime
  # See: https://discourse.nixos.org/t/immich-and-cuda-accelerated-machine-learning/58330/4
  # nixpkgs.config = {
  #   # cudaSupport = true;
  #   cudaCapabilities = ["6.1"];
  #   cudaForwardCompat = false;
  #   allowUnsupportedSystem = true;
  # };

  # nixpkgs.overlays = [
  #   (final: prev: {
  #     onnxruntime = prev.onnxruntime.override {
  #       cudaSupport = true;
  #       cudaPackages = prev.cudaPackages.overrideScope (cfinal: cprev: {
  #         flags =
  #           cprev.flags
  #           // {
  #             cudaCapabilities = ["6.1"];
  #           };
  #       });
  #     };
  #
  #     # Patch to fix broken CUDA test
  #     # immich-machine-learning = prev.immich-machine-learning.overrideAttrs (old: {
  #     #   patches =
  #     #     (old.patches or [])
  #     #     ++ [
  #     #       (pkgs.writeText "disable_cuda_test.diff" ''
  #     #         --- a/test_main.py
  #     #         +++ b/test_main.py
  #     #         @@ -285,8 +285,6 @@
  #     #                  session = OrtSession("ViT-B-32__openai")
  #     #
  #     #                  assert session.sess_options.execution_mode == ort.ExecutionMode.ORT_SEQUENTIAL
  #     #         -        assert session.sess_options.inter_op_num_threads == 1
  #     #         -        assert session.sess_options.intra_op_num_threads == 2
  #     #                  assert session.sess_options.enable_cpu_mem_arena is False
  #     #
  #     #              def test_sets_default_sess_options_does_not_set_threads_if_non_cpu_and_default_threads(self) -> None:
  #     #       '')
  #     #     ];
  #     # });
  #   })
  # ];

  systemd.tmpfiles.rules = [
    "d ${mediaDirectory} 0700 ${config.services.immich.user} ${config.services.immich.group}"
  ];

  services.immich = {
    enable = true;
    mediaLocation = mediaDirectory;

    environment = {
      TZ = "Europe/Brussels";
    };

    database.enableVectors = false;
    database.enableVectorChord = true;

    machine-learning = {
      enable = true;
      environment = {
        MACHINE_LEARNING_WORKERS = "1"; # Start with 1, 1080 Ti has 11GB VRAM
        # MACHINE_LEARNING_DEVICE_IDS = "0"; # Your GPU device ID (likely 0)
        # LD_LIBRARY_PATH = "${pkgs.python313Packages.onnxruntime}/lib:${pkgs.python313Packages.onnxruntime}/lib/python3.13/site-packages/onnxruntime/capi";
      };
    };
    settings.server.externalDomain = "https://pics.home.deraedt.dev";
    # accelerationDevices = [
    #   "/dev/nvidia0"
    #   "/dev/nvidiactl"
    #   "/dev/nvidia-uvm"
    # ];
  };

  # Force device access for ML service (the module doesn't apply accelerationDevices to ML)
  # systemd.services.immich-machine-learning.serviceConfig = {
  #   PrivateDevices = lib.mkForce false;
  #   DeviceAllow = lib.mkForce [
  #     "/dev/nvidia0"
  #     "/dev/nvidiactl"
  #     "/dev/nvidia-uvm"
  #   ];
  # };

  # video/render for iGPU access (QuickSync/OpenVINO). The GTX 1080 Ti is gone;
  # ML runs on CPU for now. TODO: wire ML to the Intel iGPU via OpenVINO
  # (immich openvino image + intel-compute-runtime + /dev/dri passthrough).
  users.users.immich.extraGroups = ["video" "render"];

  # Pin immich's uid/gid. It auto-allocated 998 during the Crucial -> A2000 move
  # (the old install had 993), which orphaned the media until it was re-chowned.
  # Pinning keeps it stable across any future fresh reinstall.
  users.users.immich.uid = 998;
  users.groups.immich.gid = 998;

  #TODO: Make better backups
  # https://wiki.nixos.org/wiki/Immich
  # https://docs.immich.app/administration/backup-and-restore
  services.restic.backups.backblaze.paths = [
    mediaDirectory
  ];

  systemd.services.immich-machine-learning.serviceConfig = {
    MemoryHigh = "4G";
    MemoryMax = "6G";
    MemorySwapMax = "0";
  };

  systemd.services.immich-server.serviceConfig = {
    MemoryHigh = "3G";
    MemoryMax = "5G";
    MemorySwapMax = "0";
  };

  services.caddy.virtualHosts."pics.home.deraedt.dev" = {
    extraConfig = ''
      reverse_proxy http://localhost:${toString config.services.immich.port}
      encode {
        zstd
        gzip
        minimum_length 1024
      }
    '';
  };
}
