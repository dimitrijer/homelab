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
  mkNetbuildHttp = { className, modules }:
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
                    inherit storeUrl;
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
          nativeBuildInputs = [ pkgs.coreutils ];
          unpackPhase = "true";

          installPhase = ''
            dstdir=$out/${targetDir}
            mkdir -p $dstdir
            cp ${build.kernel}/bzImage $dstdir/bzImage
            cp ${build.initialRamdisk}/initrd $dstdir/initrd
            cp ${build.squashfsStore} $dstdir/store.squashfs
            sha256sum $dstdir/store.squashfs | cut -d' ' -f1 > $dstdir/store.squashfs.sha256
            cp ${build.netbootIpxeScript}/netboot.ipxe $dstdir/ipxe
          '';
        };
    in
    {
      inherit netbuild;
      configuration = sys.config;
      deploy =
        let
          localHashFile = "${netbuild}/${targetDir}/store.squashfs.sha256";
          remoteHashUrl = "http://${deployHost}/nixos/${targetDir}/store.squashfs.sha256";
        in
        pkgs.writeShellScriptBin "deploy" ''
          if [ $# -ne 1 ]; then
            echo "Supply path to private key as first argument"
            exit 1
          fi

          LOCAL_HASH=$(cat ${localHashFile})
          REMOTE_HASH=$(${pkgs.curl}/bin/curl -sf "${remoteHashUrl}" 2>/dev/null || echo "")

          if [ "$LOCAL_HASH" = "$REMOTE_HASH" ]; then
            echo "Hashes match, skipping deploy for ${className}"
            exit 0
          fi

          if [ -z "$REMOTE_HASH" ]; then
            echo "No remote hash found (new deploy or hash file missing)"
          else
            echo "Hash mismatch, deploying ${className}"
            echo "  Local:  $LOCAL_HASH"
            echo "  Remote: $REMOTE_HASH"
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
  jellyfin = mkNetbuild {
    className = "jellyfin";
    modules = [
      ./classes/jellyfin.nix
    ];
  };
  adguard-home = mkNetbuild {
    className = "adguard-home";
    modules = [
      ./classes/adguard-home.nix
    ];
  };

  # HTTP-based netboot builds (store downloaded at boot and cached)
  ganeti-node-http = mkNetbuildHttp {
    className = "ganeti-node";
    modules = [
      ./classes/ganeti-node.nix
    ];
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
  jellyfin-http = mkNetbuildHttp {
    className = "jellyfin";
    modules = [ ./classes/jellyfin.nix ];
  };
  adguard-home-http = mkNetbuildHttp {
    className = "adguard-home";
    modules = [ ./classes/adguard-home.nix ];
  };
}
