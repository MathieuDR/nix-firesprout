{
  pkgs,
  lib,
  PII,
  ...
}: let
in {
  imports = [
    ./diagnostics.nix
    ./restic.nix
    ./caddy.nix
    ./actual.nix
    # ./calibre-web.nix
    ./paperless.nix
    ./immich.nix
    ./wireguard.nix
  ];
}
