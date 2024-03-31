{ pkgs ? import ./nix/default.nix { } }:

let
  sources = import ./nix/sources.nix;
  disko = sources.disko;
  hosts = import ./hosts/default.nix {
    inherit pkgs disko;
  };
in
{
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
  ganeti = import ./ganeti/default.nix { inherit pkgs; };
} // hosts
