{
  networking.hostName = "gimel";
  services.nginx.enable = true;
  services.nginx.virtualHosts."gimel.homelab" = {
    addSSL = false;
    enableACME = false;
    root = "/srv/http";
  };
}
