# Crash/freeze instrumentation for firesprout.
#
# The box hard-hangs (not an oops/panic) with nothing on disk: journald never
# flushes its buffer during a hard hang, and the crashed session's journal is
# discarded as corrupt on the recovery boot. This module makes the next freeze
# leave a trace instead of vanishing:
#
#   1. black-box recorder  - fsynced telemetry to disk every 20s (survives a total freeze)
#   2. rasdaemon + EDAC    - persistent machine-check / DRAM error recording
#   3. hardware watchdog   - sp5100_tco warm-resets on hang (self-recovery + pstore capture)
#   4. lockup -> panic     - turn silent soft/hard lockups into captured panics
#   5. netconsole -> hpi   - stream the kernel log over UDP to the Pi (192.168.178.201)
{pkgs, ...}: let
  selfIp = "192.168.178.210";
  selfIface = "enp9s0";
  piIp = "192.168.178.201";
  piMac = "d8:3a:dd:30:2a:c9"; # hpi end0
  netconsolePort = "6666";
in {
  # (2) Record machine-check exceptions. RAM here is non-ECC (amd64_edac has no
  # device to bind), so rasdaemon covers MCEs via the tracing/mcelog interface.
  boot.kernelModules = ["netconsole"];
  hardware.rasdaemon.enable = true;

  # (4) We already boot with oops=panic + panic=10, so a *detected* lockup that
  # panics will reboot in 10s and be emitted over netconsole. Flip the detectors
  # from warn-only to panic. (A true full-silicon hang won't trip these - that is
  # what the hardware watchdog below is for.)
  boot.kernel.sysctl = {
    "kernel.softlockup_panic" = 1;
    "kernel.hardlockup_panic" = 1;
    "kernel.hung_task_panic" = 1;
    "kernel.hung_task_timeout_secs" = 60;
  };

  # (3) Arm the chipset watchdog. systemd pings it every runtimeTime/2; if the
  # kernel or systemd stops responding for 60s the SP5100 resets the machine.
  systemd.watchdog.runtimeTime = "60s";

  # (5) netconsole target set up after the network is up (robust for the modular
  # Realtek NIC, where a boot-time netconsole= param would init before enp9s0 exists).
  systemd.services.netconsole-target = {
    description = "Stream kernel log to hpi via netconsole";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [pkgs.kmod pkgs.util-linux pkgs.coreutils];
    script = ''
      modprobe configfs 2>/dev/null || true
      modprobe netconsole 2>/dev/null || true
      cfg=/sys/kernel/config/netconsole
      [ -d "$cfg" ] || mount -t configfs none /sys/kernel/config 2>/dev/null || true
      t="$cfg/firesprout"
      mkdir -p "$t"
      echo 0 > "$t/enabled" 2>/dev/null || true
      echo ${selfIface} > "$t/dev_name"
      echo ${netconsolePort} > "$t/local_port"
      echo ${netconsolePort} > "$t/remote_port"
      echo ${selfIp} > "$t/local_ip"
      echo ${piIp} > "$t/remote_ip"
      echo ${piMac} > "$t/remote_mac"
      echo 1 > "$t/enabled"
    '';
  };

  # (1) Black-box recorder. Appends a fsynced snapshot every 20s so we have the
  # trend right up to the freeze even when nothing else survives.
  systemd.services.blackbox = {
    description = "Black-box telemetry recorder (fsynced)";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    path = [pkgs.lm_sensors pkgs.coreutils pkgs.gnugrep];
    preStart = "mkdir -p /var/lib/blackbox";
    script = ''
      log=/var/lib/blackbox/metrics.log
      while :; do
        if [ "$(stat -c%s "$log" 2>/dev/null || echo 0)" -gt 20000000 ]; then
          mv -f "$log" "$log.1"
        fi
        {
          printf '=== %s up=%ss load=%s\n' \
            "$(date -Iseconds)" "$(cut -d. -f1 /proc/uptime)" "$(cut -d' ' -f1-3 /proc/loadavg)"
          grep -E 'MemAvailable|MemFree|Dirty:|Writeback:' /proc/meminfo
          sensors 2>/dev/null | grep -E 'Tctl|Tdie|Composite|^temp'
          printf 'freqMHz:'
          for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
            printf ' %s' "$(($(cat "$f") / 1000))"
          done
          printf '\n'
        } >> "$log"
        sync -f "$log" 2>/dev/null || sync
        sleep 20
      done
    '';
  };
}
