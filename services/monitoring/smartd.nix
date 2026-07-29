# smartd: the deep disk safety net — runs scheduled self-tests (short daily 02:00,
# long monthly on the 1st 03:00) and alerts earlier/more granularly than Beszel's
# health-flip. Every event routes through ntfy-send.
{
  pkgs,
  ntfySend,
  ...
}: let
  notify = pkgs.writeShellApplication {
    name = "smartd-ntfy";
    runtimeInputs = [ntfySend];
    text = ''
      ntfy-send "Disk alert: ''${SMARTD_DEVICE:-?}" \
        "''${SMARTD_MESSAGE:-SMART event} [fail=''${SMARTD_FAILTYPE:-none}]" \
        "high" "floppy_disk,warning"
    '';
  };
in {
  services.smartd = {
    enable = true;
    autodetect = false;
    defaults.monitored = "-a -o on -S on -s (S/../.././02|L/../01/./03) -W 5,45,55 -m <nomailer> -M exec ${notify}/bin/smartd-ntfy";
    devices = [
      {device = "/dev/nvme0";}
      {device = "/dev/sda";}
      {device = "/dev/sdb";}
    ];
  };
}
