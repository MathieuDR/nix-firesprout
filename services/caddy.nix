{
  PII,
  pkgs,
  config,
  self,
  ...
}: let
  caddyWithHetzner = pkgs.caddy.withPlugins {
    plugins = ["github.com/caddy-dns/hetzner/v2@v2.0.0"];
    hash = "sha256-7k2K9qhbjZMR29Y+U2pnRcBBuvK5Q9vVGQH72g42+/k=";
  };
in {
  age.secrets.hetzner-api-key = {
    file = "${self}/secrets/hetzner/api-key.age";
    owner = "caddy";
  };

  services.caddy = {
    enable = true;
    package = caddyWithHetzner;
    email = PII.caddyEmail;
    environmentFile = config.age.secrets.hetzner-api-key.path;
    globalConfig = ''
      acme_dns hetzner {env.HETZNER_DNS_API_TOKEN}
    '';
  };

  networking.firewall.allowedTCPPorts = [80 443];

  environment.systemPackages = with pkgs; [
    nss
  ];
}
