{ pkgs, config, lib, modulesPath, disko, ... }:

let
  booksDir = "/var/lib/calibre";
  domain = "calibre.homelab.tel";
  mkLayout = (import ../layouts).mkLayout;
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/cert.nix
    ../modules/provisioning/keys.nix
    ../modules/provisioning/disks.nix
    (modulesPath + "/services/web-apps/calibre-web.nix")
  ];

  config =
    {
      provisioning.keys.enable = true;
      provisioning.disks.enable = true;
      provisioning.disks.ensureDirs = [{
        path = booksDir;
        owner = "calibre-web";
        group = "calibre-web";
      }];

      disko.devices = mkLayout { };

      services.calibre-web = {
        enable = true;
        listen = {
          ip = "127.0.0.1";
          port = 8083;
        };
        openFirewall = false;
        options = {
          calibreLibrary = booksDir;
          enableBookUploading = true;
          enableBookConversion = true;
        };
      };

      # Calibre requires some graphical stuff.
      environment.noXlibs = false;

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
        virtualHosts."calibre-web" = {
          rejectSSL = true;
          locations."/".return = "301 https://${domain}$request_uri";
        };
        virtualHosts."calibre" = {
          rejectSSL = true;
          locations."/".return = "301 https://${domain}$request_uri";
        };
        virtualHosts."${domain}" = {
          forceSSL = true;
          useACMEHost = "${domain}";
          locations."/" = {
            proxyPass = "http://${config.services.calibre-web.listen.ip}:${toString config.services.calibre-web.listen.port}";
          };
        };
      };
    };
}
