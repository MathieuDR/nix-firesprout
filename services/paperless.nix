{
  self,
  config,
  ...
}: let
  data = "/hot-storage/paperless/data"; # index/models: hot, stays on NVMe
  media = "/cold-storage/paperless/media"; # documents: bulk, on the HDD pool
  port = "29818";
  tikaPort = "29820";
  gotenbergPort = "29819";
  domain = "docs.home.deraedt.dev";
in {
  age.secrets = {
    "paperless/env".file = "${self}/secrets/paperless/env.age";
  };

  firesprout.homeServices.docs.extraConfig = ''
    header {
      Strict-Transport-Security "max-age=31536000; includeSubDomains"
      X-Content-Type-Options "nosniff"
      X-Frame-Options "SAMEORIGIN"
      Referrer-Policy "strict-origin-when-cross-origin"
    }
    route {
      reverse_proxy /api/documents/post_document* http://127.0.0.1:${port} {
        transport http {
          read_timeout 300s
          write_timeout 300s
        }
      }
      reverse_proxy http://127.0.0.1:${port}
    }
  '';

  # Pin uid/gid so a fresh reinstall can't drift and orphan the cold-pool media
  # (the trap immich hit: auto-allocated 993 -> 998). Current values on firesprout.
  users.users.paperless.uid = 315;
  users.groups.paperless.gid = 315;

  services.restic.backups.backblaze.paths = [
    media
    data
  ];

  # Gotenberg for Office document conversion
  virtualisation.oci-containers.containers.gotenberg = {
    image = "gotenberg/gotenberg:8";
    autoStart = true;
    ports = ["${gotenbergPort}:3000"];
    extraOptions = [
      "--user=${toString config.users.users.paperless.uid}:${toString config.users.groups.paperless.gid}"
    ];
  };

  # Tika for Office document parsing
  virtualisation.oci-containers.containers.tika = {
    image = "apache/tika:latest";
    autoStart = true;
    ports = ["${tikaPort}:9998"];
    extraOptions = [
      "--user=${toString config.users.users.paperless.uid}:${toString config.users.groups.paperless.gid}"
    ];
  };

  # systemd.slices.system-paperless.sliceConfig = {
  #   MemoryMax = "4G";
  #   MemoryHigh = "2.5G";
  # };

  systemd.targets.paperless = {
    description = "Paperless document management suite";
    wants = [
      "paperless-web.service"
      "paperless-scheduler.service"
      "paperless-consumer.service"
      "paperless-task-queue.service"
    ];
  };

  services.paperless = {
    enable = true;
    environmentFile = config.age.secrets."paperless/env".path;
    consumptionDirIsPublic = true;
    port = builtins.fromJSON port;
    address = "127.0.0.1";
    dataDir = data;
    mediaDir = media;
    user = "paperless";

    settings = {
      # === SECURITY SETTINGS FOR PUBLIC WEB ===
      PAPERLESS_URL = "https://${domain}";
      PAPERLESS_ALLOWED_HOSTS = domain;
      PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://${domain}";
      PAPERLESS_CORS_ALLOWED_HOSTS = "https://${domain}";

      # Reverse proxy configuration
      PAPERLESS_USE_X_FORWARD_HOST = true;
      PAPERLESS_USE_X_FORWARD_PORT = true;
      PAPERLESS_TRUSTED_PROXIES = "127.0.0.1";
      PAPERLESS_PROXY_SSL_HEADER = ''["HTTP_X_FORWARDED_PROTO", "https"]'';

      # === OCR SETTINGS ===
      PAPERLESS_OCR_PAGES = 1;
      PAPERLESS_OCR_LANGUAGE = "nld+deu+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
        invalidate_digital_signatures = true;
      };

      # === OFFICE DOCUMENT SUPPORT ===
      PAPERLESS_TIKA_ENABLED = true;
      PAPERLESS_TIKA_ENDPOINT = "http://127.0.0.1:${tikaPort}";
      PAPERLESS_TIKA_GOTENBERG_ENDPOINT = "http://127.0.0.1:${gotenbergPort}";

      # === OPTIONAL: BARCODE SUPPORT ===
      # PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      # PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;
      # PAPERLESS_CONSUMER_BARCODE_MAX_PAGES = 1;
    };
  };

}
