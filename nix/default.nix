{ sources ? import ./sources.nix
, config ? { }
, overlays ? [ ]
, system ? "x86_64-linux"
}:

import sources.nixpkgs {
  inherit config system;
  overlays = overlays ++ [ (import ./overlays.nix) ];
}
