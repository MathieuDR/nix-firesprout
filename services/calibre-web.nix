{...}: let
  #NOTE: We don't need to set these directories up ourselves.
  web_data_dir = "/hot-storage/calibre-web"; # app data: hot, stays on NVMe
  library = "/cold-storage/calibre-library"; # books: bulk, on the HDD pool
in {
  services.calibre-web = {
    enable = false;

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

  services.caddy.virtualHosts."books.home.deraedt.dev" = {
    extraConfig = ''
      reverse_proxy http://localhost:8883

      encode {
        zstd
        gzip
        minimum_length 1024
      }
    '';
  };
}
