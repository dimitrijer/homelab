{ pkgs ? import ./nix/default.nix { }, cmdline ? "" }:

let
  dest = "10.1.100.1";
  as = "admin";
  netbootIpxe = pkgs.writeText "netboot.ipxe" ''
    #!ipxe
    chain --replace --autofree http://${dest}/mac/''${mac:hexhyp}/ipxe
  '';
  mkNetbuild = { mac, configuration }:
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
        name = "netbuild-${mac}";
        unpackPhase = "true";

        ipxe = pkgs.writeText "netboot.ipxe" ipxeScript;

        installPhase = ''
          mkdir -p $out/mac/${mac}
          cp ${build.kernel}/bzImage $out/mac/${mac}/bzImage
          cp ${build.netbootRamdisk}/initrd $out/mac/${mac}/initrd
          cp $ipxe $out/mac/${mac}/ipxe
        '';
      };
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

in
{
  deploy =
    (pkgs.writeScriptBin "deploy" ''
      #!${pkgs.runtimeShell}
      if [ $? -ne 1 ]; then
        echo "Supply path to private key as first argument"
        exit 1
      end
      ${pkgs.openssh}/bin/scp -i "$1" -r ${alpha}/mac ${as}@${dest}:/usb1-part1/ipxe/
      ${pkgs.openssh}/bin/scp -i "$1" -r ${beta}/mac  ${as}@${dest}:/usb1-part1/ipxe/
      ${pkgs.openssh}/bin/scp -i "$1" -r ${gamma}/mac ${as}@${dest}:/usb1-part1/ipxe/
      ${pkgs.openssh}/bin/scp -i "$1" -r ${delta}/mac ${as}@${dest}:/usb1-part1/ipxe/
      ${pkgs.openssh}/bin/scp -i "$1" ${netbootIpxe} ${as}@${dest}:/usb1-part1/netboot.ipxe
    '');

  nginxIpxe = import ./nginx.nix
    {
      pkgs = pkgs.pkgsCross.aarch64-multiplatform;
    };
}
