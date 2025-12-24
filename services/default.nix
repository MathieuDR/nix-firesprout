{
  pkgs,
  lib,
  PII,
  ...
}: let
in {
  imports = [
    # ./restic.nix
    ./caddy.nix
    ./actual.nix
    # ./calibre-web.nix
    ./paperless.nix
    # ./immich.nix
  ];
}
