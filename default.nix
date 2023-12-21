{ pkgs ? import ./nix/default.nix { } }:

let
  dest = "10.1.100.1";
  as = "admin";
  mkNetbuild = { mac, configuration }:
    let
      sys =
        pkgs.nixos
          ({ config, pkgs, lib, modulesPath, ... }: {
            imports = [
              (modulesPath + "/installer/netboot/netboot.nix")
              # Allow "nixos-rebuild" to work properly by providing
              # /etc/nixos/configuration.nix.
              (modulesPath + "/profiles/clone-config.nix")
              (modulesPath + "/profiles/minimal.nix")
            ];
            config = import configuration { inherit config; };
          });
      build = sys.config.system.build;

      netbuild =
        pkgs.stdenv.mkDerivation
          {
            name = "netbuild-${mac}";
            unpackPhase = "true";

            installPhase = ''
              mkdir -p $out/mac/${mac}
              cp ${build.kernel}/bzImage $out/mac/${mac}/bzImage
              cp ${build.netbootRamdisk}/initrd $out/mac/${mac}/initrd
              cp ${build.netbootIpxeScript}/netboot.ipxe $out/mac/${mac}/ipxe
            '';
          };
    in
    {
      inherit netbuild;
      deploy =
        pkgs.writeScriptBin "deploy" ''
          #!${pkgs.runtimeShell}
          if [ $# -ne 1 ]; then
            echo "Supply path to private key as first argument"
            exit 1
          fi
          ${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/mac ${as}@${dest}:/usb1-part1/ipxe/
        '';
    };
in
rec {
  alpha = mkNetbuild {
    mac = "48-4d-7e-ee-44-9b";
    configuration = ./alpha.nix;
  };
  beta = mkNetbuild {
    mac = "48-4d-7e-ee-4d-09";
    configuration = ./beta.nix;
  };
  gamma = mkNetbuild {
    mac = "18-66-da-47-97-93";
    configuration = ./gamma.nix;
  };
  delta = mkNetbuild {
    mac = "48-4d-7e-ee-48-0d";
    configuration = ./delta.nix;
  };

  nginxIpxe = import ./nginx.nix
    {
      pkgs = pkgs.pkgsCross.aarch64-multiplatform;
    };
}
