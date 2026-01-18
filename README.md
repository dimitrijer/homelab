# Homelab NixOS Setup

This repo contains Nix files that I use to build bootable images for machines
in my homelab, both virtual and physical.

I use [Ganeti](https://ganeti.org/) for cluster management and KVM via qemu to
run virtual machines on top of it. There are four nodes in my cluster, each one
running on Dell Optiplex Micro 7040.

These nodes boot NixOS images over network. I build and deploy these images
using files in this repo.

- `nix` contains sources pinned by [niv](https://github.com/nmattia/niv). I'm using
  `nixpkgs-21.11` to build Ganeti, as most dependency versions roughly match.
  Notable exceptions are qemu, iPXE image and drbd-utils, which I cherry-pick
  from `nixpkgs-unstable`.

- `ganeti/default.nix` is Ganeti 3.0.2 derivation.

- `ganeti/os-providers/default.nix` is an attribute set of derivations of
  Ganeti OS providers. So far I only make use of
  [ganeti-os-pxe](https://github.com/hpc2n/ganeti-os-pxe) that I modify to
  write iPXE BIOS NBP from `nixpkgs-unstable` to disk instead of custom
  Etherboot NBP that is provided in that repository.

- `ipxe/netboot.ipxe` is the main iPXE script that machines in the homelab
  run first when they boot.

- `nginx/default.nix` is a derivation that contains a container image of nginx
  that runs on MikroTik ax3 router. I use this to serve iPXE scripts and NixOS
  images.

- `nixos/default.nix` contains NixOS image definitions that I call _classes_.
  Each class represents a different image. Right now there are:
  - `ganeti-node` that nodes in the cluster boot from; this is the only image
    that physical boxes use
  - `navidrome` for Navidrome
  - `calibre-web` for Calibre web server

Disks are provisioned with [disko](https://github.com/nix-community/disko), and
root and host keys are provisioned through a systemd service. Once host keys
are in place, I use [agenix](https://github.com/ryantm/agenix) to decrypt and
deploy secrets.

Nix store squashfs is cached locally on both physical and virtual machines.
During stage 1 NixOS boot, cache freshness is checked, and a new image is
downloaded if needed. After that, Nix store is mounted using overlayfs, with
squashfs contents being mounted read-only, and a tmpfs writable layer being
mounted on top of it.
