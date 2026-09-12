{ system ? "x86_64-linux" }:

let
  sources = import ./nix/sources.nix;
  pkgs = import ./nix { inherit system; };

  netbuildClasses = import ./nixos/default.nix {
    inherit pkgs;
    disko = sources.disko;
    agenix = sources.agenix;
  };

  # A directory of deploy scripts, one per image, so that any subset of images
  # can be built with a single nix-build invocation (one evaluation, and Nix
  # schedules all builds together):
  #   ./result/<image>/bin/deploy
  mkDeployFarm = names: pkgs.linkFarm "netbuilds"
    (map (name: { inherit name; path = netbuildClasses.${name}.deploy; }) names);
in
{
  inherit (pkgs)
    ovn
    ovn-bgp-agent
    ganeti
    ganeti-os-pxe
    nomad-driver-virt
    nomad-bin
    prometheus-ganeti-exporter;

  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };

  inherit mkDeployFarm;
  imageNames = builtins.attrNames netbuildClasses;
  all = mkDeployFarm (builtins.attrNames netbuildClasses);
} // netbuildClasses
