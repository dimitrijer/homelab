{ pkgs, disko, agenix }:

let
  lib = pkgs.lib;
  stdenv = pkgs.stdenv;
  deployHost = "boot.homelab.tel";
  deployUser = "admin";
  deployPath = "/usb1-part1/http/nixos/by-class/";

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
in
{
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
}
