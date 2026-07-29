# Beszel: box + container health + SMART snapshot. Hub + agent on the same box.
# KEY + TOKEN come from the hub UI "Add System" step and live in /var/lib/beszel-agent.env
# (root 600, written on-box, never in git).
{...}: {
  # Docker-compatible podman socket → the beszel-agent module auto-joins the `podman`
  # group for container stats.
  virtualisation.podman.dockerSocket.enable = true;

  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    port = 8090; # dataDir defaults to /var/lib/beszel-hub (NVMe/hot)
  };
  systemd.services.beszel-hub.serviceConfig = {
    MemoryHigh = "96M";
    MemoryMax = "128M";
  };

  services.beszel.agent = {
    enable = true;
    environmentFile = "/var/lib/beszel-agent.env"; # KEY= , TOKEN=
    environment = {
      HUB_URL = "http://127.0.0.1:8090";
      DISABLE_SSH = "true"; # WebSocket mode
      DOCKER_HOST = "unix:///run/podman/podman.sock";
      SERVICE_PATTERNS = "podman-*,beszel*,immich-*,paperless-*";
    };
    smartmon = {
      enable = true;
      deviceAllow = ["/dev/nvme0" "/dev/sda" "/dev/sdb"];
    };
  };
  systemd.services.beszel-agent.serviceConfig = {
    MemoryHigh = "48M";
    MemoryMax = "64M";
  };

  firesprout.homeServices.metrics.port = 8090;

  # Hub identity (SSH key), admin, registered systems, alert config + history.
  services.restic.backups.backblaze.paths = ["/var/lib/beszel-hub"];
}
