{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  mediaDir = "/var/lib/jellyfin-media";
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
      path = mediaDir;
      owner = "jellyfin";
      group = "users";
      mod = 775;
    }];
  };

  disko.devices = mkLayout { };

  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "jellyfin.homelab.tel";
    redirectDomains = [ "jellyfin" ];
    upstreamPort = 8096;
  };
}
