{ pkgs, config, lib, modulesPath, disko, ... }:

let
  vgState = "pool_state";
  blockDevice = "/dev/vda";
  musicDir = "/data/music";
  disko-fmt = pkgs.writeShellScriptBin "disko-fmt" "${config.system.build.formatScript}";
  disko-mnt = pkgs.writeShellScriptBin "disko-mnt" "${config.system.build.mountScript}";
in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/services/audio/navidrome.nix")
    ("${disko}/module.nix")
    ../modules/common.nix
    ../modules/provisioning/keys.nix
    ../modules/provisioning/disks.nix
  ];

  config =
    {
      provisioning.keys.enable = true;
      provisioning.disks.enable = true;
      provisioning.disks.ensureDirs = [ "/data/music" ];

      boot.kernelParams = [
        "console=tty0"
        "console=ttyS0,115200" # gnt serial console
      ];

      systemd.services."serial-getty@ttyS0" = {
        enable = true;
        wantedBy = [ "getty.target" ];
        serviceConfig.Restart = "always";
      };

      disko.devices = {
        disk.hdd = {
          device = blockDevice;
          type = "disk";
          name = "hdd";
          content = {
            type = "lvm_pv";
            vg = vgState;
          };
        };

        lvm_vg."${vgState}" = {
          type = "lvm_vg";
          lvs = {
            data = {
              size = "8G";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/data";
              };
            };
            home = {
              size = "500M";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/home";
              };
            };
            var = {
              size = "100%FREE";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/var";
              };
            };
          };
        };
      };

      services.navidrome = {
        enable = true;
        package = pkgs.navidrome;
        settings = {
          Address = "0.0.0.0";
          Port = 4533;
          MusicFolder = musicDir;
        };
        openFirewall = true;
      };

      environment.systemPackages = with pkgs;
        [
          vim
        ];
    };
}
