{ pkgs ? import ./nix/default.nix { } }:

let
  sources = import ./nix/sources.nix;
  # drbd-utils 8.4 is broken on linux kernels 5+
  # Luckily, drbd-utils 9.19 supports drbd kernel module 8.4
  disko = sources.disko;
  ganeti = import ./ganeti/default.nix {
    inherit pkgs;
    drbd = (import sources.nixpkgs-23-11 { }).drbd;
  };
  qemu = pkgs.qemu;
  nixpkgs-latest = import sources.nixpkgs-23-11 {
    overlays = [
      (self: (super:
        super // {
          inherit (ganeti) ganeti ganeti-os-pxe;
          inherit qemu;
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
  inherit (ganeti) ganeti ganeti-os-pxe;
  inherit qemu;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // hosts
