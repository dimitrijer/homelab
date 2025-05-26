{ sources ? import ./sources.nix
, config ? { }
, overlays ? [ ]
, system ? "x86_64-linux"
}:

let
  finalOverlays = import ./overlays { inherit overlays; };
in
import sources.nixpkgs {
  inherit config system;
  overlays = finalOverlays;
}
