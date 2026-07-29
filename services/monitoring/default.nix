# Tier-1 monitoring stack (all on firesprout). See monitoring-design.md / monitoring-plan.md.
{pkgs, ...}: let
  # Shared publisher used by smartd (Task 3) and OnFailure (Task 4).
  # Usage: ntfy-send "<title>" "<body>" [priority] [tags]
  ntfy-send = pkgs.writeShellApplication {
    name = "ntfy-send";
    runtimeInputs = [pkgs.curl pkgs.coreutils];
    text = ''
      title="''${1:-firesprout}"
      body="''${2:-}"
      prio="''${3:-default}"
      tags="''${4:-}"
      args=(-fsS --max-time 10 --retry 1 -H "Title: $title" -H "Priority: $prio")
      tok="$(cat /var/lib/ntfy-sh/publish-token 2>/dev/null || true)"
      if [ -n "$tok" ]; then args+=(-H "Authorization: Bearer $tok"); fi
      if [ -n "$tags" ]; then args+=(-H "Tags: $tags"); fi
      curl "''${args[@]}" -d "$body" "http://127.0.0.1:2586/firesprout" >/dev/null
    '';
  };
in {
  imports = [
    ./smart-history.nix
    ./ntfy.nix
    ./smartd.nix
    ./onfailure.nix
    ./beszel.nix
    ./gatus.nix
    # ./smartd.nix     # Task 3
    # ./onfailure.nix  # Task 4
    # ./beszel.nix     # Task 5
    # ./gatus.nix      # Task 6
  ];

  environment.systemPackages = [ntfy-send];
  # Expose to sibling modules (smartd, onfailure) so they can call it by store path.
  _module.args.ntfySend = ntfy-send;

  # SMART history log lives on the NVMe (root fs), never on the HDD pool.
  systemd.tmpfiles.rules = ["d /var/lib/smart-history 0750 root root -"];
}
