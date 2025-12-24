{...}: let
  # Hot storage, faters, backups to offsite & cold storage
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

  #TODO: BACKUPS
  # services.restic.backups.b2.paths = [
  #   data_dir
  # ];

  services.caddy.virtualHosts."actual.i.deraedt.dev" = {
    extraConfig = ''
      tls internal
      encode gzip zstd
      reverse_proxy http://localhost:5006
    '';
  };
}
