{
  self,
  config,
  ...
}: let
  mediaDirectory = "/storage/immich";
in {
  age.secrets = {
    "immich/env".file = "${self}/secrets/immich/env.age";
  };

  systemd.tmpfiles.rules = [
    "d ${mediaDirectory} 0700 ${config.services.immich.user} ${config.services.immich.group}"
  ];

  services.immich = {
    enable = false;

    secretsFile = config.age.secrets."immich/env".path;

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
      };
    };
    settings.server.externalDomain = "https://pics.home.deraedt.dev";
    accelerationDevices = null;
  };

  users.users.immich.extraGroups = ["video" "render"];
  hardware.nvidia-container-toolkit.enable = true;

  #TODO: Make better backups
  # https://wiki.nixos.org/wiki/Immich
  # https://docs.immich.app/administration/backup-and-restore
  services.restic.backups.backblaze.paths = [
    mediaDirectory
  ];

  services.caddy.virtualHosts."pics.home.deraedt.dev" = {
    extraConfig = ''
      tls internal
      reverse_proxy http://localhost:${toString config.services.immich.port}
      encode {
        zstd
        gzip
        minimum_length 1024
      }
    '';
  };
}
