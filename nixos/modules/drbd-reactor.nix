{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.drbd-reactor;
  settingsFormat = pkgs.formats.toml { };
  configFile = settingsFormat.generate "drbd-reactor.toml" cfg.settings;
in
{
  options.services.drbd-reactor = {
    enable = mkEnableOption "drbd-reactor, the DRBD event monitor";

    package = mkPackageOption pkgs "drbd-reactor" { };

    drbdPackage = mkOption {
      type = types.package;
      default = pkgs.drbd;
      defaultText = literalExpression "pkgs.drbd";
      description = "drbd-utils (>= 9.29) providing drbdadm and drbdsetup, which drbd-reactor runs";
    };

    settings = mkOption {
      type = settingsFormat.type;
      default = { };
      description = ''
        Contents of /etc/drbd-reactor.toml, including plugin sections. See
        <https://github.com/LINBIT/drbd-reactor/blob/master/example/drbd-reactor.toml>.
      '';
    };

    prometheus = {
      enable = mkEnableOption "the Prometheus exporter plugin";

      port = mkOption {
        type = types.port;
        default = 9942;
        description = "port the Prometheus exporter listens on (all addresses)";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "whether to open the Prometheus exporter port in the firewall";
      };
    };
  };

  config = mkIf cfg.enable {
    services.drbd-reactor.settings.prometheus = mkIf cfg.prometheus.enable [
      { address = ":${toString cfg.prometheus.port}"; }
    ];

    # Also read by drbd-reactorctl.
    environment.etc."drbd-reactor.toml".source = configFile;
    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts =
      mkIf (cfg.prometheus.enable && cfg.prometheus.openFirewall) [ cfg.prometheus.port ];

    systemd.services.drbd-reactor = {
      description = "DRBD-Reactor Service";
      documentation = [ "https://github.com/LINBIT/drbd-reactor" ];
      # drbd-reactor checks the loaded kernel module's version on startup.
      after = [ "systemd-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];
      reloadTriggers = [ configFile ];
      path = [ cfg.drbdPackage ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${cfg.package}/bin/drbd-reactor --config /etc/drbd-reactor.toml";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };
}
