{ pkgs, disko }:

let
  dest = "gimel";
  as = "dimitrije";

  mkNetbuild = { configuration }:
    let
      sys =
        pkgs.nixos
          ({ config, pkgs, lib, modulesPath, ... }:
            let
              modules = [
                (modulesPath + "/installer/netboot/netboot.nix")
                (modulesPath + "/profiles/minimal.nix")
                ("${disko}/module.nix")
                ./common.nix
                configuration
              ];
            in
            {
              imports = modules ++ [
                # Allow "nixos-rebuild" to work properly by providing
                # /etc/nixos/configuration.nix.
                (modulesPath + "/profiles/clone-config.nix")
              ];
              config = {
                installer.cloneConfigIncludes = modules;
              };
            });

      build = sys.config.system.build;

      netbuild =
        pkgs.stdenv.mkDerivation
          {
            name = "netbuild-${sys.config.networking.hostName}";
            unpackPhase = "true";

            installPhase = ''
              dstdir=$out/by-hostname/${sys.config.networking.hostName}
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
        pkgs.writeScriptBin "deploy" ''
          #!${pkgs.runtimeShell}
          if [ $# -ne 1 ]; then
            echo "Supply path to private key as first argument"
            exit 1
          fi
          #${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/by-hostname/${sys.config.networking.hostName} ${as}@${dest}:/usb1-part1/http/nixos/
          ${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/by-hostname/${sys.config.networking.hostName} ${as}@${dest}:/srv/http/nixos/by-hostname/
        '';
    };
in
{
  aleph = mkNetbuild {
    # mac = "48-4d-7e-ee-44-9b";
    configuration = ./hosts/aleph.nix;
  };
  bet = mkNetbuild {
    # mac = "48-4d-7e-ee-4d-09";
    configuration = ./hosts/bet.nix;
  };
  gimel = mkNetbuild {
    # mac = "18-66-da-47-97-93";
    configuration = ./hosts/gimel.nix;
  };
  dalet = mkNetbuild {
    # mac = "48-4d-7e-ee-48-0d";
    configuration = ./hosts/dalet.nix;
  };
}
