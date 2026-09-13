{ sources ? import ./sources.nix
, config ? { }
, overlays ? [ ]
, system ? "x86_64-linux"
}:

import sources.nixpkgs {
  inherit system;
  inherit config;
  overlays = import ./overlays { inherit overlays; };
}
