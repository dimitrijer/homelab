{ system ? "x86_64-linux" }:

let
  pkgs = import ./nix { inherit system; };
  ganeti = pkgs.callPackage ./ganeti { };
  ganeti-os-providers = import ./ganeti/os-providers { inherit pkgs; };
  prometheus-ganeti-exporter = pkgs.callPackage ./ganeti/prometheus-exporter { };
  netbuildClasses =
    let
      sources = import ./nix/sources.nix;
      ganetiOverlay = self: super: ganeti-os-providers // {
        inherit ganeti prometheus-ganeti-exporter;
      };
    in
    import ./nixos/default.nix {
      # Expose ganeti in pkgs.
      pkgs = import ./nix {
        inherit system;
        overlays = [ ganetiOverlay ];
      };
      disko = sources.disko;
      agenix = sources.agenix;
    };
in
{
  inherit ganeti ganeti-os-providers;
  nginx = import ./nginx/default.nix { pkgs = pkgs.pkgsCross.aarch64-multiplatform; };
} // netbuildClasses
