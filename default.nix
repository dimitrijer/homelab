{ system ? "x86_64-linux" }:

let
  sources = import ./nix/sources.nix;
  pkgs-unstable =
    let
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
    in
    import sources.nixpkgs {
      inherit system; overlays = [ qemuOverlay ];
    };
  qemuOverlay =
    self: super: {
      # Use bleeding edge qemu.
      qemu = pkgs-unstable.qemu;
      qemu-utils = pkgs-unstable.qemu-utils;
    };
  drbdOverlay = self: super: {
    # drbd-utils 8.4 is broken on linux kernels 5+
    # Luckily, drbd-utils 9+ supports drbd kernel module 8.4
    drbd = pkgs-unstable.drbd;
  };
  ovmfOverlay = self: super: {
    OVMF = pkgs-unstable.OVMF.override {
      secureBoot = true;
      tpmSupport = true;
      tlsSupport = true;
      httpSupport = true;
      msVarsTemplate = true;
      systemManagementModeRequired = false;
    };
  };
  pkgs-21-11 =
    let
      ghcOverlay = self: super: {
        # GHC 8.8.4 packages contain roughly the same versions of Ganeti dependencies.
        ghc = super.haskell.packages.ghc884;
      };
    in
    import ./nix/default.nix {
      inherit sources system;
      overlays = [ drbdOverlay qemuOverlay ghcOverlay ovmfOverlay ];
    };
  ganeti = pkgs-21-11.callPackage ./ganeti { };
  ganeti-os-providers = import ./ganeti/os-providers { pkgs = pkgs-unstable; };
  prometheus-ganeti-exporter = pkgs-unstable.callPackage ./ganeti/prometheus-exporter { };
  pkgs =
    let
      ganetiOverlay = self: super: ganeti-os-providers // {
        inherit ganeti prometheus-ganeti-exporter;
      };
      swtpmOverlay = self: super: {
        swtpm = pkgs-unstable.swtpm.overrideAttrs {
          version = "0.9.0";
          src = pkgs-unstable.fetchFromGitHub {
            owner = "stefanberger";
            repo = "swtpm";
            rev = "v0.9.0";
            hash = "sha256-IeFrS67qStklaTgM0d3F8Xt8upm2kEawT0ZPFD7JKnk=";
          };
        };
      };
    in
    import sources.nixpkgs {
      inherit system;
      overlays = [ ganetiOverlay qemuOverlay swtpmOverlay ovmfOverlay ];
    };
  netbuildClasses = import ./nixos/default.nix {
    inherit pkgs;
    disko = sources.disko;
    agenix = sources.agenix;
  };
in
{
  inherit ganeti ganeti-os-providers;
  OVMF = pkgs-21-11.OVMF;
  swtpm = pkgs.swtpm;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // netbuildClasses
