# Beszel: box + container health + SMART snapshot. Hub + agent on the same box.
# KEY + TOKEN come from the hub UI "Add System" step and live in /var/lib/beszel-agent.env
{...}: {
  virtualisation.podman.dockerSocket.enable = true;

  services.beszel.hub = {
    enable = true;
    # Bind to the WireGuard IP so remote agents (e.g. nix-dock) can connect over
    # the tunnel; local agent + caddy reach it via lo (always allowed).
    host = "10.100.0.2";
    port = 8090; # dataDir defaults to /var/lib/beszel-hub (NVMe/hot)
  };

  # The hub binds a WG-interface IP, which only exists once wg0 is up.
  systemd.services.beszel-hub = {
    after = ["wireguard-wg0.service"];
    requires = ["wireguard-wg0.service"];
  };

  # Remote agents dial in over wg0; loopback traffic is accepted by default.
  networking.firewall.interfaces.wg0.allowedTCPPorts = [8090];

  services.beszel.agent = {
    enable = true;
    environmentFile = "/var/lib/beszel-agent.env"; # KEY= , TOKEN=
    environment = {
      HUB_URL = "http://10.100.0.2:8090";
      DISABLE_SSH = "true"; # WebSocket mode
      DOCKER_HOST = "unix:///run/podman/podman.sock";
      SERVICE_PATTERNS = "podman-*,beszel*,immich-*,paperless-*,gatus*";
    };
    smartmon = {
      enable = true;
      deviceAllow = ["/dev/nvme0" "/dev/sda" "/dev/sdb"];
    };
  };

  firesprout.homeServices.metrics.host = "10.100.0.2";
  firesprout.homeServices.metrics.port = 8090;

  # Hub identity (SSH key), admin, registered systems, alert config + history.
  services.restic.backups.backblaze.paths = ["/var/lib/beszel-hub"];
}
