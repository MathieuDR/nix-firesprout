{
  pkgs,
  lib,
  PII,
  self,
  ...
}: let
in {
  age.secrets = {
    "common/ghp".file = "${self}/secrets/common/ghp.age";
  };

  imports = [
    ./restic.nix
    ./caddy.nix
    ./actual.nix
    # ./calibre-web.nix
    ./paperless.nix
    ./immich.nix
    ./wireguard.nix
    ./mealie.nix
  ];
}
