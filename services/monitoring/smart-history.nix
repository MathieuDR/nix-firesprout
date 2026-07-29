# Weekly machine-readable SMART snapshot -> /var/lib/smart-history/smart.jsonl.
# `-x` captures attributes + error log + self-test log; smartd (Task 3) runs the
# self-tests whose results land here. This is the cheap "poor-man's Scrutiny" history.
{pkgs, ...}: let
  devices = ["/dev/nvme0" "/dev/sda" "/dev/sdb"];
  snapshot = pkgs.writeShellApplication {
    name = "smart-history-snapshot";
    runtimeInputs = [pkgs.smartmontools pkgs.jq pkgs.coreutils];
    text = ''
      ts="$(date -Iseconds)"
      out=/var/lib/smart-history/smart.jsonl
      for d in ${toString devices}; do
        # smartctl's exit code is a bitmask (non-zero even on success when SMART
        # warnings are set), so ignore it and validate the JSON with jq instead.
        raw="$(smartctl --json=c -x "$d" || true)"
        if printf '%s' "$raw" | jq -e . >/dev/null 2>&1; then
          printf '%s' "$raw" | jq -c --arg ts "$ts" --arg dev "$d" \
            '{ts: $ts, device: $dev, smart: .}' >> "$out"
        else
          printf '{"ts":"%s","device":"%s","error":"no json"}\n' "$ts" "$d" >> "$out"
        fi
      done
    '';
  };
in {
  systemd.services.smart-history = {
    description = "Append a smartctl --json snapshot to the SMART history log";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${snapshot}/bin/smart-history-snapshot";
    };
  };
  systemd.timers.smart-history = {
    description = "Weekly SMART history snapshot";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  services.restic.backups.backblaze.paths = ["/var/lib/smart-history"];
}
