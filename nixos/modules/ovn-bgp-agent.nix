{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.ovn-bgp-agent;

  configFile = pkgs.writeText "bgp-agent.conf" ''
    [DEFAULT]
    debug = ${if cfg.debug then "True" else "False"}

    [ovn]
    ovn_nb_connection = ${cfg.ovn.nbConnection}
    ovn_sb_connection = ${cfg.ovn.sbConnection}
    ovs_db_connection = ${cfg.ovs.connection}

    [agent]
    driver = ${cfg.driver}
    expose_tenant_networks = ${if cfg.exposeTenantNetworks then "True" else "False"}

    ${cfg.extraConfig}
  '';
in
{
  options.services.ovn-bgp-agent = {
    enable = mkEnableOption "OVN BGP Agent";

    package = mkOption {
      type = types.package;
      default = pkgs.ovn-bgp-agent;
      defaultText = literalExpression "pkgs.ovn-bgp-agent";
      description = "OVN BGP Agent package to use";
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging";
    };

    driver = mkOption {
      type = types.enum [ "ovn_bgp_driver" "nb_ovn_bgp_driver" ];
      default = "nb_ovn_bgp_driver";
      description = ''
        BGP driver to use.
        - ovn_bgp_driver: Uses OVN Southbound DB
        - nb_ovn_bgp_driver: Uses OVN Northbound DB
      '';
    };

    exposeTenantNetworks = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to expose tenant networks through BGP";
    };

    ovn = {
      nbConnection = mkOption {
        type = types.str;
        default = "tcp:127.0.0.1:6641";
        description = "OVN Northbound database connection string";
        example = "ssl:127.0.0.1:6641";
      };

      sbConnection = mkOption {
        type = types.str;
        default = "tcp:127.0.0.1:6642";
        description = "OVN Southbound database connection string";
        example = "ssl:127.0.0.1:6642";
      };
    };

    ovs = {
      connection = mkOption {
        type = types.str;
        default = "tcp:127.0.0.1:6640";
        description = "OVS database connection string";
      };
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra configuration to append to bgp-agent.conf";
      example = ''
        [bgp]
        AS = 64999
        router_id = 192.0.2.1
      '';
    };
  };

  config = mkIf cfg.enable {
    # Ensure OVN is enabled as a dependency
    assertions = [
      {
        assertion = config.virtualisation.ovn.enable or false;
        message = "services.ovn-bgp-agent requires virtualisation.ovn.enable = true";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    # Create configuration directory and file
    environment.etc."ovn-bgp-agent/bgp-agent.conf".source = configFile;

    systemd.services.ovn-bgp-agent = {
      description = "OVN BGP Agent";
      documentation = [ "https://docs.openstack.org/ovn-bgp-agent/latest/" ];

      wants = [ "network-online.target" ];
      after = [ "network-online.target" "ovn-controller.service" ];
      requires = [ "ovn-controller.service" ];

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        ExecStart = "${cfg.package}/bin/ovn-bgp-agent --config-dir /etc/ovn-bgp-agent";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = false; # Needs privileges for network configuration
        ReadWritePaths = [ "/run" "/var/lib/ovn-bgp-agent" ];

        # Capabilities needed for network operations
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      };
    };

    # Create state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/ovn-bgp-agent 0755 root root -"
    ];
  };
}
