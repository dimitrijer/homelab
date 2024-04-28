{ sources ? import ./sources.nix
, config ? { }
, overlays ? [ ]
, system ? "x86_64-linux"
}:

import sources.nixpkgs-21-11 {
  inherit config system overlays;
}
