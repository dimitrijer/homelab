{ system ? "x86_64-linux" }:

let
  sources = import ./nix/sources.nix;
  pkgs = import ./nix { inherit system; };
  # Use nixpkgs-unstable for packages that need a newer Go toolchain
  pkgsUnstable = import sources.nixpkgs-unstable { inherit system; };
  ovn = pkgs.callPackage ./ovn { };
  openstackPythonPackages = import ./openstack { inherit pkgs; };
  ovn-bgp-agent = pkgs.callPackage ./ovn-bgp-agent {
    inherit openstackPythonPackages;
    ovs = ovn;
  };
  ganeti = pkgs.callPackage ./ganeti { openvswitch = ovn; };
  ganeti-os-providers = import ./ganeti/os-providers { inherit pkgs; };
  prometheus-ganeti-exporter = pkgs.callPackage ./ganeti/prometheus-exporter { };
  nomad-driver-virt = pkgsUnstable.callPackage ./nomad { };
  netbuildClasses =
    let
      ganetiOverlay = self: super: ganeti-os-providers // {
        inherit ganeti prometheus-ganeti-exporter;
      };
      ovnOverlay = self: super: {
        inherit ovn ovn-bgp-agent;
      };
      nomadOverlay = self: super: {
        inherit nomad-driver-virt;
      };
    in
    import ./nixos/default.nix {
      # Expose ganeti in pkgs.
      pkgs = import ./nix {
        inherit system;
        overlays = [ ganetiOverlay ovnOverlay nomadOverlay ];
        # Nomad is licensed under BSL
        config.allowUnfreePredicate = pkg:
          builtins.elem (pkgs.lib.getName pkg) [ "nomad" ];
      };
      disko = sources.disko;
      agenix = sources.agenix;
    };
in
{
  inherit ovn ovn-bgp-agent ganeti ganeti-os-providers nomad-driver-virt;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // netbuildClasses
