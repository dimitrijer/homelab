{ sources ? import ./sources.nix
, config ? { }
, overlays ? [ ]
, system ? "x86_64-linux"
}:

import sources.nixpkgs {
  inherit system;
  config = {
    # Nomad is licensed under BSL.
    allowUnfreePredicate = pkg: builtins.elem (pkg.pname or "") [ "nomad" ];
  } // config;
  overlays = import ./overlays { inherit overlays; };
}
