{
  self,
  pkgs,
  lib,
  config,
  ...
}: let
  # Originals live on the cold HDD pool; the regenerable derived data (thumbnails,
  # transcodes) is symlinked back to the NVMe so browsing/playback never wakes the
  # spindles. immich follows the symlinks transparently.
  mediaDirectory = "/cold-storage/immich";
  hotDirectory = "/hot-storage/immich-hot";
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

  systemd.tmpfiles.rules = let
    u = config.services.immich.user;
    g = config.services.immich.group;
  in [
    # NVMe home for the regenerable derived data (always-mounted /hot-storage)
    "d ${hotDirectory} 0700 ${u} ${g} - -"
    "d ${hotDirectory}/thumbs 0700 ${u} ${g} - -"
    "d ${hotDirectory}/encoded-video 0700 ${u} ${g} - -"
  ];

  # Symlink the regenerable derived dirs onto the NVMe. Done as a mount-ordered
  # oneshot rather than tmpfiles L+: during `nixos-rebuild switch`, tmpfiles runs
  # before /cold-storage remounts, so an L+ symlink lands on the underlying dir and
  # gets shadowed by the mount. RequiresMountsFor guarantees both mounts are live.
  systemd.services.immich-media-links = {
    description = "Point immich thumbnails/transcodes at the NVMe";
    before = ["immich-server.service" "immich-machine-learning.service"];
    requiredBy = ["immich-server.service"];
    unitConfig.RequiresMountsFor = [mediaDirectory hotDirectory];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ln -sfn ${hotDirectory}/thumbs        ${mediaDirectory}/thumbs
      ln -sfn ${hotDirectory}/encoded-video ${mediaDirectory}/encoded-video
      chown -h ${config.services.immich.user}:${config.services.immich.group} ${mediaDirectory}/thumbs ${mediaDirectory}/encoded-video
    '';
  };

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
        MACHINE_LEARNING_WORKERS = "1"; # 1 worker; ML runs on CPU for now
      };
    };
    settings.server.externalDomain = "https://pics.home.deraedt.dev";
  };

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

}
