# Beszel: box + container health + SMART snapshot. Hub + agent on the same box.
# KEY + TOKEN come from the hub UI "Add System" step and live in /var/lib/beszel-agent.env
{...}: {
  virtualisation.podman.dockerSocket.enable = true;

  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    port = 8090; # dataDir defaults to /var/lib/beszel-hub (NVMe/hot)
  };

  services.beszel.agent = {
    enable = true;
    environmentFile = "/var/lib/beszel-agent.env"; # KEY= , TOKEN=
    environment = {
      HUB_URL = "http://127.0.0.1:8090";
      DISABLE_SSH = "true"; # WebSocket mode
      DOCKER_HOST = "unix:///run/podman/podman.sock";
      SERVICE_PATTERNS = "podman-*,beszel*,immich-*,paperless-*,gatus*";
    };
    smartmon = {
      enable = true;
      deviceAllow = ["/dev/nvme0" "/dev/sda" "/dev/sdb"];
    };
  };

  firesprout.homeServices.metrics.port = 8090;

  # Hub identity (SSH key), admin, registered systems, alert config + history.
  services.restic.backups.backblaze.paths = ["/var/lib/beszel-hub"];
}
