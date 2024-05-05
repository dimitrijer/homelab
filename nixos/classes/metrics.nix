{ pkgs, config, lib, modulesPath, disko, ... }:

let
  domain = "metrics.homelab.tel";
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/cert.nix
    ../modules/provisioning/keys.nix
    ../modules/provisioning/disks.nix
  ];

  services.grafana = {
    enable = true;
    dataDir = "/var/lib/grafana";
    settings = {
      server = {
        inherit domain;
      };
    };
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    scrapeConfigs = [
      {
        job_name = "prometheus";
        scrape_interval = "15s";
        static_configs = [{
          targets = [ "localhost:9090" ];
        }];
      }
      {
        job_name = "node";
        scrape_interval = "15s";
        dns_sd_configs = [{
          names = [ "scrape-targets.homelab.tel" ];
          refresh_interval = "300s";
        }];
      }
    ];
  };

  provisioning.keys.enable = true;
  provisioning.disks = {
    enable = true;
    ensureDirs = [ config.services.grafana.dataDir ];
  };

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

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.acme.certs."${domain}" = { group = "nginx"; };

  systemd.services."acme-${domain}" = {
    after = [ "agenix-install-secrets.service" ];
    requires = [ "agenix-install-secrets.service" ];
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    virtualHosts."metrics" = {
      rejectSSL = true;
      locations."/".return = "301 https://${domain}$request_uri";
    };
    virtualHosts."${domain}" = {
      forceSSL = true;
      useACMEHost = "${domain}";
      locations."/" = {
        proxyPass = "http://${config.services.grafana.settings.server.http_addr}:${toString config.services.grafana.settings.server.http_port}";
        proxyWebsockets = true;
      };
    };
  };
}
