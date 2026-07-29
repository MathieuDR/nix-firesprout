# Gatus: black-box up/down for every service. Endpoints are one attrset each,
# grouped by host — delete a line to cull. Alerts go to ntfy via the token that
# Task 2 wrote to /var/lib/ntfy-sh/publish-token.env (read as ${NTFY_TOKEN}).
# Local firesprout services with a working *.home cert are checked over HTTPS;
# ntfy/beszel (no DNS record yet) are checked on localhost.
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
in {
  systemd.services.gatus.serviceConfig = {
    EnvironmentFile = "/var/lib/ntfy-sh/publish-token.env";
    MemoryHigh = "48M";
    MemoryMax = "64M";
  };

  firesprout.homeServices.status.port = 8095;

  services.gatus = {
    enable = true;
    settings = {
      web.port = 8095;
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
      ];
    };
  };
}
