{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.services.ovn-bgp-agent;

  format = pkgs.formats.ini { };

  configFile = format.generate "bgp-agent.conf" cfg.settings;

  defaultSettings = {
    DEFAULT = mkDefault {
      debug = false;
      bgp_AS = 65001;
      bgp_router_id = "192.168.0.2";
      expose_tenant_networks = false;
      require_snat_disabled_for_tenant_networks = true;
      exposing_method = "underlay";
      advertisement_method_tenant_networks = "host";
      ovsdb_connection = "unix:/var/run/openvswitch/db.sock";
      disable_ipv6 = true;
      log_file = "/var/log/ovn-bgp-agent/ovn-bgp-agent.log";
      use_stderr = false;
    };
    ovn = mkDefault {
      ovn_nb_connection = "tcp:127.0.0.1:6641";
      ovn_sb_connection = "tcp:127.0.0.1:6642";
    };
  };
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

    settings = mkOption {
      type = format.type;
      default = defaultSettings;
      description = ''
        Configuration for ovn-bgp-agent. See
        <https://github.com/openstack/ovn-bgp-agent/blob/master/ovn_bgp_agent/config.py>
        for available options.
      '';
      example = literalExpression ''
        {
          DEFAULT = {
            debug = false;
            bgp_AS = 65001;
            bgp_router_id = "192.168.0.2";
            expose_tenant_networks = false;
            require_snat_disabled_for_tenant_networks = true;
            exposing_method = "underlay";
            advertisement_method_tenant_networks = "host";
            ovsdb_connection = "unix:/var/run/openvswitch/db.sock";
          };
          ovn = mkDefault {
            ovn_nb_connection = "tcp:127.0.0.1:6641";
            ovn_sb_connection = "tcp:127.0.0.1:6642";
          };
        }
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

    # Needed for additional routing tables.
    networking.iproute2.enable = true;

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

      # Create routing tables file if it doesn't exist
      # ovn-bgp-agent needs to append to this file
      preStart = ''
                if [ ! -f /etc/iproute2/rt_tables ]; then
                  mkdir -p /etc/iproute2
                  cat > /etc/iproute2/rt_tables << 'EOF'
        #
        # reserved values
        #
        255	local
        254	main
        253	default
        0	unspec
        #
        # local
        #
        EOF
        fi
      '';

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        ExecStart = "${cfg.package}/bin/ovn-bgp-agent --config-dir /etc/ovn-bgp-agent";
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    # Create log directories
    systemd.tmpfiles.rules = [
      "d /var/log/ovn-bgp-agent 0755 root root -"
    ];
  };
}
