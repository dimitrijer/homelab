{ pkgs ? import ./nix/default.nix { }, cmdline ? "" }:

let
  mkNetbuild = { name, configuration }:
    let
      sys =
        pkgs.nixos
          ({ config, pkgs, lib, modulesPath, ... }: {
            imports = [
              (modulesPath + "/installer/netboot/netboot-minimal.nix")
            ];
            config = import configuration { inherit config; };
          });
      build = sys.config.system.build;
      ipxeScript = ''
        #!ipxe
        # Use the cmdline variable to allow the user to specify custom kernel params
        # when chainloading this script from other iPXE scripts like netboot.xyz
        kernel bzImage init=${build.toplevel}/init initrd=initrd nohibernate loglevel=4 ${cmdline}
        initrd initrd
        boot
      '';

    in
    pkgs.stdenv.mkDerivation
      {
        name = "netbuild-${name}";
        unpackPhase = "true";

        netbootIpxe = pkgs.writeText "netboot-${name}.ipxe" ipxeScript;

        installPhase = ''
          mkdir -p $out
          cp ${build.kernel}/bzImage $out/bzImage-${name}
          cp ${build.netbootRamdisk}/initrd $out/initrd-${name}
          cp $netbootIpxe $out/netboot-${name}.ipxe
        '';
      };
in
{
  alpha = mkNetbuild {
    name = "alpha";
    configuration = ./alpha.nix;
  };
  beta = mkNetbuild {
    name = "beta";
    configuration = ./beta.nix;
  };


  nginxIpxe = import ./nginx.nix
    {
      pkgs = pkgs.pkgsCross.aarch64-multiplatform;
    };
}
