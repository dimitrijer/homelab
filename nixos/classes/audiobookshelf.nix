{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  dataDir = "/var/lib/audiobookshelf";
  audiobooksDir = "/var/lib/audiobooks";
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/acme-nginx-reverse-proxy.nix
    ../modules/provisioning/disks.nix
  ];

  provisioning.disks = {
    enable = true;
    ensureDirs = [
      {
        path = dataDir;
        owner = "audiobookshelf";
        group = "audiobookshelf";
        mod = 755;
      }
      {
        path = audiobooksDir;
        owner = "audiobookshelf";
        group = "users";
        mod = 775;
      }
    ];
  };

  disko.devices = mkLayout { };

  services.audiobookshelf = {
    enable = true;
    dataDir = builtins.baseNameOf dataDir;
    openFirewall = false;
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "audiobookshelf.homelab.tel";
    redirectDomains = [ "audiobookshelf" ];
    upstreamPort = config.services.audiobookshelf.port;
  };
}
