{
  pkgs,
  self,
  config,
  ...
}: {
  age.secrets = {
    "codeberg/runner".file = "${self}/secrets/codeberg/runner.age";
  };

  # docker:// job labels need a Docker-API socket. firesprout runs podman, so expose
  # its socket at the usual Docker location and point the runner at it.
  virtualisation.podman.dockerSocket.enable = true;

  # The native executor builds/pushes the garden image by talking to the rootful
  # podman API socket (via DOCKER_HOST). Grant the runner user group access to it.
  # Builds therefore run as root on the host, same trust level as docker-socket access.
  users.groups.podman = {};
  systemd.sockets.podman.socketConfig = {
    SocketMode = "0660";
    SocketGroup = "podman";
  };
  users.users.gitea-runner.extraGroups = ["podman"];

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.default = {
      enable = true;
      name = "firesprout";
      url = "https://codeberg.org";

      tokenFile = config.age.secrets."codeberg/runner".path;

      labels = [
        "ubuntu-latest:docker://node:22-bookworm"
        "ubuntu-24.04:docker://node:22-bookworm"
        "native:host"
      ];
    };
  };

  systemd.services.gitea-runner-default = {
    environment.DOCKER_HOST = "unix:///run/podman/podman.sock";
    # native executor needs a container client + ssh on PATH to build, push and deploy.
    path = [pkgs.docker-client pkgs.openssh];
  };
}
