{
  config,
  self,
  ...
}: {
  age.secrets."vaultwarden/env".file = "${self}/secrets/vaultwarden/env.age";

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = config.age.secrets."vaultwarden/env".path;
    config = {
      DOMAIN = "https://vault.home.deraedt.dev";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = true;
      SIGNUPS_VERIFY = false;
    };
  };

  # Publish behind the existing wildcard Caddy vhost (no new ACME challenge, no open port).
  firesprout.homeServices.vault.port = 8222;

  # Ride the existing nightly Backblaze job.
  services.restic.backups.backblaze.paths = ["/var/lib/bitwarden_rs"];
}
