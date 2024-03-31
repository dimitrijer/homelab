{ pkgs, disko, qemu, ganeti }:

let
  dest = "10.1.100.1";
  as = "admin";

  mkNetbuild = { mac, configuration }:
    let
      sys =
        pkgs.nixos
          ({ config, pkgs, lib, modulesPath, ... }:
            let
              common-config = import ./common.nix { inherit pkgs config qemu ganeti; };
              host-config = configuration { inherit pkgs config; };
            in
            {
              imports = [
                (modulesPath + "/installer/netboot/netboot.nix")
                # Allow "nixos-rebuild" to work properly by providing
                # /etc/nixos/configuration.nix.
                (modulesPath + "/profiles/clone-config.nix")
                (modulesPath + "/profiles/minimal.nix")
                ("${disko}/module.nix")
              ];
              config = common-config // host-config;
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
          ${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/mac ${as}@${dest}:/usb1-part1/http/nixos/
        '';
    };
in
{
  aleph = mkNetbuild {
    mac = "48-4d-7e-ee-44-9b";
    configuration = import ./hosts/aleph.nix;
  };
  bet = mkNetbuild {
    mac = "48-4d-7e-ee-4d-09";
    configuration = import ./hosts/bet.nix;
  };
  gimel = mkNetbuild {
    mac = "18-66-da-47-97-93";
    configuration = import ./hosts/gimel.nix;
  };
  dalet = mkNetbuild {
    mac = "48-4d-7e-ee-48-0d";
    configuration = import ./hosts/dalet.nix;
  };
}
