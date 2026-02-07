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

  services.adguardhome = {
    enable = true;
    mutableSettings = true;
    openFirewall = true;
    settings = {
      http.address = "127.0.0.1:3000";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
      };
    };
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "adguard-home.homelab.tel";
    redirectDomains = [ "adguard-home" "adguard" "dns" ];
    upstreamPort = 3000;
  };

  # Open DNS port (openFirewall only opens the web UI port)
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
