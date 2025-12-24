{...}: let
  #NOTE: We don't need to set these directories up ourselves.
  web_data_dir = "/hot-storage/calibre-web";
  library = "/storage/calibre-library";
in {
  services.calibre-web = {
    enable = true;

    dataDir = web_data_dir;
    listen = {
      port = 8883;
      ip = "127.0.0.1";
    };

    options = {
      enableBookUploading = false;
      calibreLibrary = library;
    };
  };

  # systemd.services."podman-calibre-web" = {
  #   partOf = ["service-tools.target"];
  #   wantedBy = ["service-tools.target"];
  # };

  #TODO: Backups
  # services.restic.backups.b2.paths = [
  #   "/var/lib/${web_data_dir}"
  #   library
  # ];

  services.caddy.virtualHosts."books.local" = {
    extraConfig = ''
      tls internal
      reverse_proxy http://localhost:8883

      encode {
        zstd
        gzip
        minimum_length 1024
      }
    '';
  };
}
