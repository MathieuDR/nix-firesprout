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
    serviceConfig = {
      SupplementaryGroups = lib.mkForce [];
      # systemd mounts the DynamicUser StateDirectory noexec; the job workspace
      # lives under it and CI must execute tool binaries it installs there
      # (esbuild and other native npm deps), so carve the runner's work tree
      # back to executable. Still unprivileged: this only re-enables exec inside
      # its own scratch dir, not root or podman access.
      ExecPaths = ["/var/lib/gitea-runner"];
    };
    path = [pkgs.nix pkgs.skopeo pkgs.openssh];
  };
}
