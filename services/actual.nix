{...}: let
  data_dir = "/hot-storage/actual/";
in {
  virtualisation.oci-containers.containers.actual = {
    image = "actualbudget/actual-server:latest";
    autoStart = true;

    volumes = [
      "${data_dir}:/data"
    ];

    ports = [
      "5006:5006"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${data_dir} 0664 root root"
  ];

  services.restic.backups.backblaze.paths = [
    data_dir
  ];

  services.caddy.virtualHosts."actual.home.deraedt.dev" = {
    extraConfig = ''
      tls internal
      encode gzip zstd
      reverse_proxy http://localhost:5006
    '';
  };
}
