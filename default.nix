{ system ? "x86_64-linux" }:

let
  pkgs = import ./nix { inherit system; };
  ovn = pkgs.callPackage ./ovn { };
  openstackPythonPackages = import ./openstack { inherit pkgs; };
  ovn-bgp-agent = pkgs.callPackage ./ovn-bgp-agent { inherit openstackPythonPackages; };
  ganeti = pkgs.callPackage ./ganeti { openvswitch = ovn; };
  ganeti-os-providers = import ./ganeti/os-providers { inherit pkgs; };
  prometheus-ganeti-exporter = pkgs.callPackage ./ganeti/prometheus-exporter { };
  netbuildClasses =
    let
      sources = import ./nix/sources.nix;
      ganetiOverlay = self: super: ganeti-os-providers // {
        inherit ganeti prometheus-ganeti-exporter;
      };
      ovnOverlay = self: super: {
        inherit ovn;
      };
    in
    import ./nixos/default.nix {
      # Expose ganeti in pkgs.
      pkgs = import ./nix {
        inherit system;
        overlays = [ ganetiOverlay ovnOverlay ];
      };
      disko = sources.disko;
      agenix = sources.agenix;
    };
in
{
  inherit ovn ovn-bgp-agent ganeti ganeti-os-providers;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // netbuildClasses
