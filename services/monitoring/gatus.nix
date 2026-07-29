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
  pingEp = name: target: {
    inherit name;
    group = "net";
    url = "icmp://${target}";
    interval = "60s";
    conditions = ["[CONNECTED] == true" "[RESPONSE_TIME] < 80"];
    alerts = ntfyAlert;
  };
in {
  systemd.services.gatus.serviceConfig = {
    EnvironmentFile = "/var/lib/ntfy-sh/publish-token.env";
    # Go + sqlite + concurrent TLS checks spike past a tight cap; 48M throttled it
    # into constant memory-reclaim stalls (the "lag"). Give it real headroom.
    MemoryHigh = "192M";
    MemoryMax = "256M";
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
        # --- VPS public  ---
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
        # (pingEp "google" "8.8.8.8")
      ];
    };
  };
}
