{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  dataDir = "/var/lib/immich";
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
      path = dataDir;
      owner = "immich";
      group = "users";
    }];
  };

  disko.devices = mkLayout { };

  services.immich = {
    enable = true;
    mediaLocation = dataDir;
    openFirewall = false;
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "immich.homelab.tel";
    redirectDomains = [ "immich" ];
    upstreamPort = config.services.immich.port;
  };
}
