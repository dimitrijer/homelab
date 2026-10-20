{ config, lib, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  # On the var LV, not tmpfs. Nix rejects a build-dir with any world-writable
  # (or symlinked) ancestor, which rules out /var/tmp and /tmp.
  buildDir = "/var/lib/nix-build";
  cachePublicKey = "homelab:K6YXD2QHUbgKijhBl7jebtNadNqd9ZhN5qi6qt7Im80=";
  # Keys the workstations' nix-daemon (i.e. root) uses to reach the builders,
  # see `nix.buildMachines.*.sshKey` on the client. Must have no passphrase.
  clientKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAN+vX8041z3Hy7GtfXJqJ8FpJTuUKi4Tcuzyym/7j88 nixbuild@skiff"
    ];
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/provisioning/disks.nix
  ];

  provisioning.disks = {
    enable = true;
    ensureDirs = [{ path = buildDir; }];
  };

  disko.devices = mkLayout { };

  # Stable SSH host keys across reboots, so that clients' known_hosts keep
  # working. Requires <hostname>.tar.gz on the boot server.
  provisioning.keys.enable = true;

  # Build outputs and substituted inputs go to the var LV instead of RAM.
  netboot-http.rwStoreOnDisk = true;

  users.users.nixbuild = {
    isSystemUser = true;
    group = "nixbuild";
    useDefaultShell = true;
    # ssh-ng only needs to run `nix-daemon --stdio`: no pty, no forwarding.
    openssh.authorizedKeys.keys = map (key: "restrict ${key}") clientKeys;
  };
  users.groups.nixbuild = { };

  nix.settings = {
    trusted-users = [ "nixbuild" ];
    # Concurrency is mostly driven by the clients' `maxJobs`; let each job
    # use all vCPUs.
    max-jobs = 2;
    cores = 0;
    build-dir = buildDir;
    # Auto-GC: the store only holds scratch, everything worth keeping is
    # copied back to the client (and from there pushed to nix-cache).
    min-free = 3 * 1024 * 1024 * 1024;
    max-free = 8 * 1024 * 1024 * 1024;
  } // lib.optionalAttrs (cachePublicKey != "") {
    extra-substituters = [ "https://nix-cache.homelab.tel/homelab" ];
    extra-trusted-public-keys = [ cachePublicKey ];
  };
}
