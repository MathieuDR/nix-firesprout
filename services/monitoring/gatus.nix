# Gatus: black-box up/down for every service. Endpoints are one attrset each,
# grouped by host — delete a line to cull. Alerts go to ntfy via the token that
# Task 2 wrote to /var/lib/ntfy-sh/publish-token.env (read as ${NTFY_TOKEN}).
# Home services are checked over HTTPS (full DNS/Caddy/TLS path); a net group pings
# 1.1.1.1/8.8.8.8 (ICMP) to catch internet loss / latency. History persists via sqlite.
# HTTP endpoints are up/down only (no latency alert) — home ~50ms vs VPS ~150-170ms
# means a single response-time threshold would false-alarm; latency lives on the net pings.
{...}: let
  ntfyAlert = [
    {
      type = "ntfy";
      "failure-threshold" = 3;
      "success-threshold" = 2;
      "send-on-resolved" = true;
    }
  ];
  ep = name: url: group: {
    inherit name group url;
    interval = "60s";
    conditions = ["[CONNECTED] == true" "[STATUS] < 400"];
    alerts = ntfyAlert;
  };
  # ICMP ping check (no HTTP status); 150ms grace (normal ping is ~20ms) so it only
  # fires on real internet loss or congestion.
  pingEp = name: target: {
    inherit name;
    group = "net";
    url = "icmp://${target}";
    interval = "60s";
    conditions = ["[CONNECTED] == true" "[RESPONSE_TIME] < 150"];
    alerts = ntfyAlert;
  };
in {
  systemd.services.gatus.serviceConfig = {
    EnvironmentFile = "/var/lib/ntfy-sh/publish-token.env";
    MemoryHigh = "48M";
    MemoryMax = "64M";
  };

  firesprout.homeServices.status.port = 8095;

  services.restic.backups.backblaze.paths = ["/var/lib/gatus"];

  services.gatus = {
    enable = true;
    settings = {
      web.port = 8095;
      # Persist check history across restarts (default storage is in-memory).
      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/gatus.db";
      };
      alerting.ntfy = {
        url = "http://127.0.0.1:2586";
        topic = "firesprout";
        token = "\${NTFY_TOKEN}";
        priority = 4;
      };
      endpoints = [
        # --- home (firesprout) ---
        (ep "immich" "https://pics.home.deraedt.dev/api/server/ping" "home")
        (ep "paperless" "https://docs.home.deraedt.dev" "home")
        (ep "actual" "https://actual.home.deraedt.dev" "home")
        (ep "mealie" "https://recipes.home.deraedt.dev/api/app/about" "home")
        (ep "ntfy" "https://ntfy.home.deraedt.dev/v1/health" "home")
        (ep "beszel" "https://metrics.home.deraedt.dev" "home")
        # --- public ---
        (ep "website" "https://mathieu.deraedt.dev" "public")
        (ep "foundry" "https://drakkenheim.deraedt.dev" "public")
        # --- VPS public (cull freely; confirm hosts from nix-dock) ---
        (ep "glance" "https://glance.deraedt.dev" "vps")
        (ep "garden" "https://garden.deraedt.dev" "vps")
        # (ep "ghostfolio" "https://invest.deraedt.dev" "vps")
        (ep "commafeed" "https://feed.deraedt.dev" "vps")
        (ep "readdeck" "https://readlater.deraedt.dev" "vps")
        (ep "shlink" "https://l.deraedt.dev" "vps")
        (ep "goatcounter" "https://insights.deraedt.dev" "vps")
        # (ep "ddb-proxy" "https://ddb-proxy.deraedt.dev" "vps")
        # --- internet connectivity (ICMP) ---
        (pingEp "cloudflare" "1.1.1.1")
        (pingEp "google" "8.8.8.8")
      ];
    };
  };
}
