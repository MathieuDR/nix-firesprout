# Per-unit crash/OOM alerts
{
  config,
  lib,
  pkgs,
  ntfySend,
  ...
}: let
  containerNames =
    map (n: "podman-${n}")
    (lib.attrNames config.virtualisation.oci-containers.containers);
  nativeNames = [
    "immich-server"
    "immich-machine-learning"
    "paperless-web"
    "paperless-scheduler"
    "paperless-consumer"
    "paperless-task-queue"
    "caddy"
    "beszel"
    "gatus"
    "restic-backups-backblaze"
  ];
  watched = lib.unique (containerNames ++ nativeNames);

  failScript = pkgs.writeShellApplication {
    name = "ntfy-failure";
    runtimeInputs = [ntfySend pkgs.systemd];
    text = ''
      unit="''${1:-unknown}"
      tail="$(journalctl -u "$unit" -n 15 --no-pager 2>/dev/null || true)"
      ntfy-send "Service failed: $unit" "$tail" "max" "rotating_light"
    '';
  };
in {
  systemd.services =
    (lib.genAttrs watched (_: {
      onFailure = ["ntfy-failure@%n.service"];
    }))
    // {
      "ntfy-failure@" = {
        description = "Notify ntfy that %i failed";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${failScript}/bin/ntfy-failure %i";
        };
      };
    };
}
