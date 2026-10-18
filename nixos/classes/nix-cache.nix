{ config, pkgs, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  port = 8080;
in
{
  imports = [
    ../modules/common-vm.nix
    ../modules/acme-nginx-reverse-proxy.nix
    ../modules/provisioning/disks.nix
  ];

  provisioning.disks.enable = true;

  disko.devices = mkLayout { };

  # Attic binary cache. SQLite database and chunk storage live under
  # /var/lib/atticd (the module's defaults), i.e. on the var LV.
  services.atticd = {
    enable = true;
    # ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=...
    environmentFile = config.age.secrets.atticd-env.path;
    settings = {
      listen = "127.0.0.1:${toString port}";
      api-endpoint = "https://nix-cache.homelab.tel/";
      garbage-collection = {
        interval = "12 hours";
        # Drop paths nobody has pulled for this long.
        default-retention-period = "3 months";
      };
    };
  };

  age.secrets.atticd-env.file = ../secrets/atticd-env.age;

  systemd.services.atticd = {
    after = [ "agenix-install-secrets.service" ];
    requires = [ "agenix-install-secrets.service" ];
  };

  # `attic` CLI for cache administration (`atticd-atticadm` mints tokens).
  environment.systemPackages = [ pkgs.attic-client ];

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "nix-cache.homelab.tel";
    redirectDomains = [ "nix-cache" ];
    upstreamPort = port;
    # NAR uploads are unbounded in size and can take a while.
    extraConfig = ''
      client_max_body_size 0;
      proxy_request_buffering off;
      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
    '';
  };
}
