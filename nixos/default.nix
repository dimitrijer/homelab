{ pkgs, disko }:

let
  dest = "10.1.100.1";
  as = "dimitrije";

  mkNetbuild = { className, modules }:
    let
      sys =
        pkgs.nixos
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
          ${pkgs.openssh}/bin/scp -i "$1" -r ${netbuild}/${targetDir} ${as}@${dest}:/srv/http/nixos/by-class/
        '';
    };
in
{
  ganeti-node = mkNetbuild {
    className = "ganeti-node";
    modules = [
      ./classes/ganeti-node.nix
      ("${disko}/module.nix")
    ];
  };
}
