# Self-hosted ntfy: the single alert sink. Auth is provisioned on-box (ntfy mints
# the token at runtime, so it can't live in agenix). Senders read the token from
# /var/lib/ntfy-sh/publish-token; the phone uses the token or the `alerts` login.
{
  config,
  pkgs,
  ...
}: let
  port = 2586;
in {
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.home.deraedt.dev";
      listen-http = "127.0.0.1:${toString port}";
      behind-proxy = true;
      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "deny-all";
      # Persist the message cache (survives restarts) and keep a week of history,
      # so alerts fired while nothing was subscribed still catch up.
      cache-file = "/var/lib/ntfy-sh/cache.db";
      cache-duration = "168h";
    };
  };

  systemd.services.ntfy-sh.serviceConfig = {
    MemoryHigh = "48M";
    MemoryMax = "64M";
  };

  firesprout.homeServices.ntfy.port = port;

  # Auth db (users/token/ACL) + message cache; keeps the phone logged in across a restore.
  services.restic.backups.backblaze.paths = ["/var/lib/ntfy-sh"];

  # Idempotent: create the `alerts` user (random on-box password), grant rw on the
  # topic, and mint one access token → publish-token{,.env} for senders/Gatus.
  systemd.services.ntfy-provision = {
    description = "Provision ntfy alerts user + publish token";
    after = ["ntfy-sh.service"];
    requires = ["ntfy-sh.service"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.ntfy-sh pkgs.coreutils];
    environment = {
      NTFY_AUTH_FILE = "/var/lib/ntfy-sh/user.db";
      NTFY_AUTH_DEFAULT_ACCESS = "deny-all";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      dir=/var/lib/ntfy-sh
      for _ in $(seq 1 30); do [ -f "$dir/user.db" ] && break; sleep 1; done

      if ! ntfy user list 2>/dev/null | grep -q '^user alerts'; then
        pw="$(head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 24)"
        umask 077
        printf '%s' "$pw" > "$dir/alerts-password"
        printf '%s\n%s\n' "$pw" "$pw" | ntfy user add alerts
      fi
      ntfy access alerts firesprout rw || true

      if [ ! -s "$dir/publish-token" ]; then
        tok="$(ntfy token add alerts 2>/dev/null | grep -oE 'tk_[A-Za-z0-9_-]+' | head -n1)"
        umask 077
        printf '%s' "$tok" > "$dir/publish-token"
        printf 'NTFY_TOKEN=%s\n' "$tok" > "$dir/publish-token.env"
      fi
    '';
  };

}
