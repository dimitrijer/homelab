{}:

let
  pkgs = import ./nix/default.nix { };
  sources = import ./nix/sources.nix;
  ganeti = pkgs.callPackage ./ganeti/default.nix {
    # drbd-utils 8.4 is broken on linux kernels 5+
    # Luckily, drbd-utils 9.19 supports drbd kernel module 8.4
    drbd = (import sources.nixpkgs-23-11 { }).drbd;
  };
  ganeti-os-providers = import ./ganeti/os-providers/default.nix { inherit pkgs; };
  qemu = pkgs.qemu;
  pkgs-23-11 = import sources.nixpkgs-23-11 {
    overlays = [
      (self: (super:
        super // {
          inherit ganeti qemu;
        } // ganeti-os-providers
      ))
    ];
  };
  netbuildClasses = import ./nixos/default.nix {
    pkgs = pkgs-23-11;
    disko = sources.disko;
  };
in
{
  nginx = import ./nginx/default.nix { pkgs = pkgs-23-11.pkgsCross.aarch64-multiplatform; };
} // netbuildClasses
