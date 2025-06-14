{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  musicDir = "/var/lib/navidrome-music";
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
      path = musicDir;
      owner = "navidrome";
      group = "users";
      mod = 775;
    }];
  };

  disko.devices = mkLayout { };

  services.navidrome = {
    enable = true;
    settings.MusicFolder = musicDir;
    openFirewall = false;
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "navidrome.homelab.tel";
    redirectDomains = [ "navidrome" ];
    upstreamPort = config.services.navidrome.settings.Port;
  };
}
