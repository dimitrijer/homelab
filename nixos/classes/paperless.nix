{ config, ... }:

let
  mkLayout = (import ../layouts).mkLayout;
  dataDir = "/var/lib/paperless";
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
      owner = "paperless";
      group = "paperless";
    }];
  };

  disko.devices = mkLayout { };

  services.paperless = {
    inherit dataDir;
    enable = true;
    port = 8080;
    consumptionDirIsPublic = true;
    passwordFile = config.age.secrets.paperless-admin-password.path;
  };

  # Paperless requires some graphical stuff.
  environment.noXlibs = false;

  age.secrets.paperless-admin-password =
    {
      file = ../secrets/paperless-admin-password.age;
      owner = config.services.paperless.user;
    };

  systemd.services.paperless-scheduler = {
    after = [ "agenix-install-secrets.service" ];
    requires = [ "agenix-install-secrets.service" ];
  };

  services.acme-nginx-reverse-proxy = {
    enable = true;
    domain = "paperless.homelab.tel";
    redirectDomains = [ "paperless" "paperless-ng" ];
    upstreamPort = config.services.paperless.port;
  };
}
