{ pkgs, disko, agenix }:

let
  lib = pkgs.lib;
  stdenv = pkgs.stdenv;
  deployHost = "boot.homelab.tel";
  deployUser = "admin";
  deployPath = "/usb1-part1/http/nixos/by-class/";

  # Original netboot builder (embeds entire store in initrd)
  mkNetbuild = { className, modules }:
    let
      sys =
        (import (pkgs.path + "/nixos/lib/eval-config.nix") {
          specialArgs.disko = disko;
          specialArgs.agenix = agenix;
          modules = [
            ({ modulesPath, ... }:
              let
                allModules = modules ++ [
                  (modulesPath + "/installer/netboot/netboot.nix")
                ];
              in
              {
                imports = allModules ++ [
                  # Allow "nixos-rebuild" to work properly by providing
                  # /etc/nixos/configuration.nix.
                  (modulesPath + "/profiles/clone-config.nix")
                ];
                config.installer.cloneConfigIncludes = modules;
                config.nixpkgs.pkgs = lib.mkDefault pkgs;
                config.nixpkgs.localSystem = lib.mkDefault stdenv.hostPlatform;
                # Do not require signatures, to allow copying derivations and closures from local store.
                config.nix.settings.require-sigs = false;
                # Use faster compression for squashfs to speed up builds
                config.netboot.squashfsCompression = "zstd -Xcompression-level 1";
              })
          ];
          system = null;
        });

      build = sys.config.system.build;

      targetDir = "by-class/${className}";
      netbuild =
        pkgs.stdenv.mkDerivation
          {
            name = "netbuild-${className}";
            unpackPhase = "true";

            installPhase = ''
              dstdir=$out/${targetDir}
              mkdir -p $dstdir
              cp ${build.kernel}/bzImage $dstdir/bzImage
              cp ${build.netbootRamdisk}/initrd $dstdir/initrd
              cp ${build.netbootIpxeScript}/netboot.ipxe $dstdir/ipxe
            '';
          };
    in
    {
      inherit netbuild;
      configuration = sys.config;
      deploy =
        pkgs.writeShellScriptBin "deploy" ''
          if [ $# -ne 1 ]; then
            echo "Supply path to private key as first argument"
            exit 1
          fi
          ${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/${targetDir} ${deployUser}@${deployHost}:${deployPath}
        '';
    };

  # New HTTP-based netboot builder (downloads store from boot server)
  # cache options: { enable ? true, volumeGroup ? "pool_state", path ? "/var/cache/netboot/store.squashfs" }
  mkNetbuildHttp = { className, modules, cache ? { }, httpProxy ? "" }:
    let
      storeUrl = "http://${deployHost}/nixos/by-class/${className}/store.squashfs";

      sys =
        (import (pkgs.path + "/nixos/lib/eval-config.nix") {
          specialArgs.disko = disko;
          specialArgs.agenix = agenix;
          modules = [
            ({ modulesPath, ... }:
              let
                allModules = modules ++ [
                  ./modules/netboot-http.nix
                ];
              in
              {
                imports = allModules ++ [
                  # Allow "nixos-rebuild" to work properly by providing
                  # /etc/nixos/configuration.nix.
                  (modulesPath + "/profiles/clone-config.nix")
                ];
                config = {
                  installer.cloneConfigIncludes = modules;
                  nixpkgs.pkgs = lib.mkDefault pkgs;
                  nixpkgs.localSystem = lib.mkDefault stdenv.hostPlatform;
                  # Do not require signatures, to allow copying derivations and closures from local store.
                  nix.settings.require-sigs = false;

                  netboot-http = {
                    enable = true;
                    inherit storeUrl cache httpProxy;
                  };
                };
              })
          ];
          system = null;
        });

      build = sys.config.system.build;

      targetDir = "by-class/${className}";

      netbuild =
        pkgs.stdenv.mkDerivation {
          name = "netbuild-http-${className}";
          unpackPhase = "true";

          installPhase = ''
            dstdir=$out/${targetDir}
            mkdir -p $dstdir
            cp ${build.kernel}/bzImage $dstdir/bzImage
            cp ${build.initialRamdisk}/initrd $dstdir/initrd
            cp ${build.squashfsStore} $dstdir/store.squashfs
            cp ${build.netbootIpxeScript}/netboot.ipxe $dstdir/ipxe
          '';
        };
    in
    {
      inherit netbuild;
      configuration = sys.config;
      deploy =
        pkgs.writeShellScriptBin "deploy" ''
          if [ $# -ne 1 ]; then
            echo "Supply path to private key as first argument"
            exit 1
          fi
          ${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/${targetDir} ${deployUser}@${deployHost}:${deployPath}
        '';
    };
in
{
  # Traditional netboot builds (store embedded in initrd)
  calibre-web = mkNetbuild {
    className = "calibre-web";
    modules = [
      ./classes/calibre-web.nix
    ];
  };
  ganeti-node = mkNetbuild {
    className = "ganeti-node";
    modules = [
      ./classes/ganeti-node.nix
    ];
  };
  navidrome = mkNetbuild {
    className = "navidrome";
    modules = [
      ./classes/navidrome.nix
    ];
  };
  metrics = mkNetbuild {
    className = "metrics";
    modules = [
      ./classes/metrics.nix
    ];
  };
  paperless = mkNetbuild {
    className = "paperless";
    modules = [
      ./classes/paperless.nix
    ];
  };
  audiobookshelf = mkNetbuild {
    className = "audiobookshelf";
    modules = [
      ./classes/audiobookshelf.nix
    ];
  };

  # HTTP-based netboot builds (store downloaded at boot)
  # Caching is enabled by default (uses /dev/pool_state/var)
  # To disable: cache = { enable = false; };
  # To customize: cache = { volumeGroup = "my_vg"; path = "/var/cache/store.squashfs"; };
  ganeti-node-http = mkNetbuildHttp {
    className = "ganeti-node";
    modules = [
      ./classes/ganeti-node.nix
    ];
    cache = {
      volumeGroup = "pool_host";
    };
    # We can't initialize enp0s31f6 (e1000e) NIC at boot because of some AMT
    # madness, so we initialize secondary NIC enp3s0 (igc), and use a proxy
    # to download the squashfs.
    httpProxy = "http://10.1.97.1:8080";
  };

  calibre-web-http = mkNetbuildHttp {
    className = "calibre-web";
    modules = [ ./classes/calibre-web.nix ];
  };
  navidrome-http = mkNetbuildHttp {
    className = "navidrome";
    modules = [ ./classes/navidrome.nix ];
  };
  paperless-http = mkNetbuildHttp {
    className = "paperless";
    modules = [ ./classes/paperless.nix ];
  };
  metrics-http = mkNetbuildHttp {
    className = "metrics";
    modules = [ ./classes/metrics.nix ];
  };
  audiobookshelf-http = mkNetbuildHttp {
    className = "audiobookshelf";
    modules = [ ./classes/audiobookshelf.nix ];
  };
}
