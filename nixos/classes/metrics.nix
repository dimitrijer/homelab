{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  dataDir = "/var/lib/grafana";
  domain = "metrics.homelab.tel";
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/acme-nginx-reverse-proxy.nix
    ../modules/provisioning/disks.nix
  ];

  services.grafana = {
    inherit dataDir;
    enable = true;
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
      {
        job_name = "ganeti";
        scrape_interval = "15s";
        static_configs = [{
          targets = [ "gnt.homelab.tel:8000" ];
        }];
      }
    ];
  };

  provisioning.disks = {
    enable = true;
    ensureDirs = [{
      path = config.services.grafana.dataDir;
      owner = "grafana";
      group = "grafana";
    }];
  };

  disko.devices = mkLayout { };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    inherit domain;
    redirectDomains = [ "metrics" "grafana" ];
    upstreamAddress = config.services.grafana.settings.server.http_addr;
    upstreamPort = config.services.grafana.settings.server.http_port;
  };
}
