{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/acme-nginx-reverse-proxy.nix
    ../modules/provisioning/disks.nix
  ];

  provisioning.disks.enable = true;

  disko.devices = mkLayout { };

  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = "3001";
    };
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "uptime-kuma.homelab.tel";
    redirectDomains = [ "uptime-kuma" "uptime" "status" ];
    upstreamPort = 3001;
  };
}
