{ pkgs }:

{
  ganeti-os-pxe = pkgs.callPackage ./ganeti-os-pxe.nix { };
}
