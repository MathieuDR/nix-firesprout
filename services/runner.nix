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

  systemd.services.gitea-runner-default.environment.DOCKER_HOST = "unix:///run/podman/podman.sock";
}
