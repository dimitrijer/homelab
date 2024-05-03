{ config, pkgs, modulesPath, ... }:

let
  musicDir = "/data/music";
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/cert.nix
    ../modules/provisioning/keys.nix
    ../modules/provisioning/disks.nix
    (modulesPath + "/services/audio/navidrome.nix")
  ];

  config =
    {
      provisioning.keys.enable = true;
      provisioning.disks.enable = true;
      provisioning.disks.ensureDirs = [ musicDir ];

      disko.devices = let vgState = "pool_state"; in {
        disk.hdd = {
          device = "/dev/vda";
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
        settings.MusicFolder = musicDir;
        openFirewall = false;
      };

      networking.firewall.allowedTCPPorts = [ 80 443 ];

      security.acme.certs."navidrome.homelab.tel" = { group = "nginx"; };
      systemd.services."acme-navidrome.homelab.tel".after = [ "agenix-install-secrets.service" ];
      systemd.services."acme-navidrome.homelab.tel".requires = [ "agenix-install-secrets.service" ];

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        virtualHosts."navidrome" = {
          rejectSSL = true;
          locations."/".return = "301 https://navidrome.homelab.tel$request_uri";
        };
        virtualHosts."navidrome.homelab.tel" = {
          forceSSL = true;
          useACMEHost = "navidrome.homelab.tel";
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString config.services.navidrome.settings.Port}";
          };
        };
      };
    };
}
