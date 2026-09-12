{ overlays ? [ ] }:

# Order matters only in that homelab.nix consumes the attributes defined by
# the overlays before it (qemu-minimal, OVMF-nosmm, drbd-*).
[
  (import ./qemu.nix)
  (import ./ovmf.nix)
  (import ./drbd.nix)
  (import ./homelab.nix)
] ++ overlays
