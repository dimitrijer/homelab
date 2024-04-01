{ pkgs ? import ./nix/default.nix { } }:

let
  sources = import ./nix/sources.nix;
  disko = sources.disko;
  ganeti = import ./ganeti/default.nix { inherit pkgs; };
  qemu = pkgs.qemu;
  nixpkgs-latest = import sources.nixpkgs-23-11 {
    overlays = [
      (self: (super:
        super // {
          inherit ganeti qemu;
        }
      ))
    ];
  };
  hosts = import ./nixos/default.nix {
    pkgs = nixpkgs-latest;
    inherit disko;
  };
in
{
  inherit ganeti qemu;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // hosts
