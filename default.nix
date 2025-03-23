{ system ? "x86_64-linux" }:

let
  sources = import ./nix/sources.nix;
  # Just use qemu features / targets that are actually needed.
  qemuOverrides = {
    hostCpuTargets = [ "i386-softmmu" "x86_64-softmmu" ];
    vncSupport = true;
    alsaSupport = false;
    pulseSupport = false;
    pipewireSupport = false;
    sdlSupport = false;
    jackSupport = false;
    gtkSupport = false;
    smartcardSupport = false;
    spiceSupport = false;
    ncursesSupport = false;
    usbredirSupport = false;
    xenSupport = false;
    cephSupport = false;
    glusterfsSupport = false;
    openGLSupport = false;
    virglSupport = false;
  };
  qemuOverlay = self: super: {
    qemu = super.qemu.override qemuOverrides;
    qemu-utils = super.qemu.override (qemuOverrides // { toolsOnly = true; });
  };
  ovmfOverlay = self: super: {
    OVMF = super.OVMF.override {
      secureBoot = true;
      tpmSupport = true;
      tlsSupport = true;
      httpSupport = true;
      msVarsTemplate = true;
      systemManagementModeRequired = false;
    };
  };
  ghcOverlay = self: super: {
    ghc = super.haskell.packages.ghc96;
  };
  pkgs =
    import sources.nixpkgs {
      inherit system;
      overlays = [ qemuOverlay ovmfOverlay ghcOverlay ];
    };
  ganeti = pkgs.callPackage ./ganeti { };
  ganeti-os-providers = import ./ganeti/os-providers { inherit pkgs; };
  prometheus-ganeti-exporter = pkgs.callPackage ./ganeti/prometheus-exporter { };
  netbuildClasses =
    let
      ganetiOverlay = self: super: ganeti-os-providers // {
        inherit ganeti prometheus-ganeti-exporter;
      };
    in
    import ./nixos/default.nix {
      # Expose ganeti in pkgs.
      pkgs = import sources.nixpkgs {
        inherit system;
        overlays = [ ganetiOverlay qemuOverlay ovmfOverlay ];
      };
      disko = sources.disko;
      agenix = sources.agenix;
    };
in
{
  inherit ganeti ganeti-os-providers;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // netbuildClasses
