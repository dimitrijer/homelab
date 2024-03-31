{ pkgs ? import ./nix/default.nix { } }:

let
  sources = import ./nix/sources.nix;
  disko = sources.disko;
  nixpkgs-latest = import sources.nixpkgs-23-11 { };
  ganeti = import ./ganeti/default.nix { inherit pkgs; };
  hosts = import ./nixos/default.nix {
    inherit ganeti disko;
    qemu = pkgs.qemu;
    pkgs = nixpkgs-latest;
  };
in
{
  inherit ganeti;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // hosts
