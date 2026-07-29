{
  PII,
  pkgs,
  lib,
  config,
  self,
  ...
}: let
  caddyWithHetzner = pkgs.caddy.withPlugins {
    plugins = ["github.com/caddy-dns/hetzner/v2@v2.0.0"];
    hash = "sha256-7k2K9qhbjZMR29Y+U2pnRcBBuvK5Q9vVGQH72g42+/k=";
  };

  homeBase = "home.deraedt.dev";

  # One handle block per registered home service, matched by host.
  mkHandle = sub: c: ''
    @${sub} host ${sub}.${homeBase}
    handle @${sub} {
      ${
      if c.extraConfig != ""
      then c.extraConfig
      else if c.port != null
      then "reverse_proxy http://${c.host}:${toString c.port}"
      else throw "firesprout.homeServices.${sub}: set either port or extraConfig"
    }
    }
  '';
  homeRoutes = lib.concatStringsSep "\n" (lib.mapAttrsToList mkHandle config.firesprout.homeServices);
in {
  options.firesprout.homeServices = lib.mkOption {
    default = {};
    description = ''
      Services published at <name>.${homeBase}. Each entry becomes a host-matched
      handle in a single wildcard Caddy vhost (one DNS-01 challenge + one cert for
      all of them), so services declare their own route without triggering a
      per-subdomain ACME challenge.
    '';
    example = lib.literalExpression ''{ pics.port = 2283; }'';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        host = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Backend host to reverse_proxy to.";
        };
        port = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Backend port for the default reverse_proxy (ignored if extraConfig is set).";
        };
        extraConfig = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Raw Caddyfile inside this service's handle block (overrides the default reverse_proxy).";
        };
      };
    });
  };

  config = {
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
        acme_ca https://acme-v02.api.letsencrypt.org/directory
        acme_dns hetzner {env.HETZNER_DNS_API_TOKEN}
      '';

      # Single wildcard vhost + cert for every *.home service, generated from
      # firesprout.homeServices (declared by the service modules themselves).
      virtualHosts."*.${homeBase}".extraConfig = ''
        encode {
          zstd
          gzip
          minimum_length 1024
        }

        ${homeRoutes}

        handle {
          respond "unknown home service" 404
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [80 443];

    environment.systemPackages = with pkgs; [nss];
  };
}
