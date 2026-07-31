{
  pkgs,
  self,
  config,
  lib,
  ...
}: {
  age.secrets = {
    "codeberg/runner".file = "${self}/secrets/codeberg/runner.age";
  };

  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.default = {
      enable = true;
      name = "firesprout";
      url = "https://codeberg.org";

      tokenFile = config.age.secrets."codeberg/runner".path;

      # Native (host) executor only. Without a docker:// executor the runner has
      # no reason to touch the rootful podman socket — see the lock-down below.
      labels = ["native:host"];
    };
  };

  # Lock the runner down. Jobs run on the host as the unprivileged DynamicUser;
  # the only privileged thing they reach is the nix daemon (a sandboxed build
  # boundary, not a root shell). The module would otherwise add the `podman`
  # group (podman is enabled host-wide for other services), which lets a native
  # job reach the root podman socket and escalate, so strip it. The build needs
  # nix (build image), skopeo (push), openssh (deploy); node and git come from
  # the module.
  systemd.services.gitea-runner-default = {
    serviceConfig.SupplementaryGroups = lib.mkForce [];
    path = [pkgs.nix pkgs.skopeo pkgs.openssh];
  };
}
