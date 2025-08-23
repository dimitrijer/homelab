{ config, modulesPath, lib, agenix, ... }:

with lib;

let
  cfg = config.services.acme-nginx-reverse-proxy;
in
{
  imports = [
    "${agenix}/modules/age.nix"
    ./provisioning/keys.nix
  ];

  options.services.acme-nginx-reverse-proxy = {
    enable = mkEnableOption "nginx reverse proxy with ACME certificate renewal";

    domain = mkOption {
      type = types.str;
      description = "main domain to serve";
    };

    redirectDomains = mkOption {
      type = types.listOf types.str;
      description = "list of additional domains that will redirect to the main domain";
      default = [ ];
    };

    upstreamAddress = mkOption {
      type = types.str;
      description = "address of server to proxy";
      default = "127.0.0.1";
    };

    upstreamPort = mkOption {
      type = types.ints.positive;
      description = "port of server to proxy";
    };

    extraConfig = mkOption {
      type = types.str;
      description = "additional nginx config to include for virtual host location";
      default = "";
    };
  };

  config = mkIf cfg.enable {

    # Keys are required to decrypt secrets.
    provisioning.keys.enable = true;

    networking.firewall.allowedTCPPorts = [ 80 443 ];

    services.nginx =
      let
        redirectVirtualHosts = builtins.listToAttrs (map
          (redirectDomain: {
            name = redirectDomain;
            value = {
              rejectSSL = true;
              locations."/".return = "301 https://${cfg.domain}$request_uri";
            };
          })
          cfg.redirectDomains);
      in
      {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        virtualHosts = {
          "${cfg.domain}" = {
            forceSSL = true;
            useACMEHost = cfg.domain;
            locations."/" = {
              proxyPass = "http://${cfg.upstreamAddress}:${toString cfg.upstreamPort}";
              proxyWebsockets = true;
            };
          };
        } // redirectVirtualHosts;
      };

    security.acme = {
      acceptTerms = true;
      certs."${cfg.domain}" = { group = "nginx"; };
      defaults = {
        email = "templaryum@gmail.com";
        dnsProvider = "namecheap";
        credentialsFile = config.age.secrets.namecheap-ini.path;
        # Cannot use system resolver since it's going to resolve to local addresses.
        dnsResolver = "1.1.1.1:53";
      };
    };

    age = {
      secrets.namecheap-ini =
        {
          file = ../secrets/namecheap.ini.age;
          owner = "nginx";
        };
      identityPaths = [ "/etc/ssh/ssh_host_rsa_key" ];
      asOneshotService = true;
    };

    systemd.services."provision-keys" = {
      requiredBy = [ "agenix-install-secrets.service" ];
      before = [ "agenix-install-secrets.service" ];
    };

    systemd.services."acme-${cfg.domain}" = {
      after = [ "agenix-install-secrets.service" ];
      requires = [ "agenix-install-secrets.service" ];
    };
  };
}
