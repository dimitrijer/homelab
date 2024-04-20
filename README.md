# Homelab NixOS Setup

- `nix` contains sources pinned by niv, and some custom overlays. I'm using
  nixpkgs 21.11 to build Ganeti, as most dependency versions roughly match.
  Notable exception is `drbd-utils`, which I cherry-pick from nixpkgs 23.11.

- `ganeti/default.nix` is Ganeti 3.0.2 derivation.

- `ganeti/os-providers/default.nix` is an attribute set of derivations of
  Ganeti OS providers. So far I only use
  [ganeti-os-pxe](https://github.com/hpc2n/ganeti-os-pxe) that I modify to
  boot iPXE BIOS binary from nixpkgs instead of custom Etherboot NBP.

- `ipxe/netboot.ipxe` is the main iPXE script that servers in my homelab boot
  first.

- `nginx/default.exe` is a derivation that contains a container image of nginx
  that runs on MikroTik ax3 router and serves boot files.

- `nixos/default.nix` contains NixOS netbuild classes definitions. For now I
  only have `ganeti-node`.
