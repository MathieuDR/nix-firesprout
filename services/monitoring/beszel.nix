# Beszel: box + container health + SMART snapshot. Hub + agent on the same box.
# The agent needs a KEY (hub public key) + TOKEN from the hub UI's "Add system" step,
# so it's wired in a second pass (Task 5b) once those live in secrets/beszel/agent-env.age.
# The hub, the podman docker-socket (so the agent can later read container stats), and the
# vhost go in now.
{...}: {
  # Docker-compatible podman socket → the beszel-agent module then auto-joins the
  # `podman` group for container stats (see monitoring-plan.md).
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

  # --- Task 5b: uncomment once KEY + TOKEN are in secrets/beszel/agent-env.age ---
  # services.beszel.agent = {
  #   enable = true;
  #   environmentFile = config.age.secrets."beszel/agent-env".path;  # KEY=, TOKEN=
  #   environment.HUB_URL = "http://127.0.0.1:8090";
  #   smartmon = {
  #     enable = true;
  #     deviceAllow = ["/dev/nvme0" "/dev/sda" "/dev/sdb"];
  #   };
  # };
  # systemd.services.beszel-agent.serviceConfig = {
  #   MemoryHigh = "48M";
  #   MemoryMax = "64M";
  # };

}
