{ pkgs, drbd }:

{
  ganeti = pkgs.callPackage ./ganeti.nix { inherit drbd; };

  ganeti-os-pxe = pkgs.callPackage ./ganeti-os-pxe.nix { };
}
