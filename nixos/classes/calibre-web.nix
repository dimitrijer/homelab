{ config, ... }:

let
  booksDir = "/var/lib/calibre";
  mkLayout = (import ../layouts).mkLayout;
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/acme-nginx-reverse-proxy.nix
    ../modules/provisioning/disks.nix
  ];

  provisioning.disks = {
    enable = true;
    ensureDirs = [{
      path = booksDir;
      owner = "calibre-web";
      group = "calibre-web";
    }];
  };

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

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "calibre.homelab.tel";
    redirectDomains = [ "calibre" "calibre-web" ];
    upstreamAddress = config.services.calibre-web.listen.ip;
    upstreamPort = config.services.calibre-web.listen.port;
  };
}
