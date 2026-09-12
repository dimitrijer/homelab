# Every package that is custom to this repository, in one overlay, so that
# `import ./nix { }` is the single package set shared by the standalone
# `nix-build -A ganeti` style targets and the NixOS images.
self: super: {
  ovn = self.callPackage ../../ovn { };

  openstackPythonPackages = import ../../openstack { pkgs = self; };

  ovn-bgp-agent = self.callPackage ../../ovn-bgp-agent {
    inherit (self) openstackPythonPackages;
    ovs = self.ovn;
  };

  ganeti = self.callPackage ../../ganeti {
    openvswitch = self.ovn;
    drbd = self.drbd-utils-9;
    # Ganeti's Haskell library dependencies. Keep this on the default compiler:
    # Hydra only caches Haskell libraries for `haskellPackages`, any other GHC
    # package set means compiling them all locally.
    haskellPackages = self.haskellPackages;
    hscolour = self.haskellPackages.hscolour;
  };

  ganeti-os-pxe = self.callPackage ../../ganeti/os-providers/ganeti-os-pxe.nix { };

  prometheus-ganeti-exporter = self.callPackage ../../ganeti/prometheus-exporter { };

  nomad-driver-virt = self.callPackage ../../nomad { };

  # HashiCorp's release binary. nixpkgs' nomad is BSL-licensed and therefore
  # never built by Hydra; building it from source costs a full Go build on
  # every nixpkgs bump.
  nomad-bin = self.callPackage ../../nomad/nomad-bin.nix { };
}
