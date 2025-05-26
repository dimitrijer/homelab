{ overlays ? [ ] }:

[
  (import ./qemu.nix)
  (import ./ovmf.nix)
  (import ./ghc.nix)
  (import ./pandoc.nix)
] ++ overlays
