{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.services.frr-bgp;
in
{
  options.services.frr-bgp = {
    enable = mkEnableOption "FRR BGP configuration with dynamic node-specific settings";

    localAS = mkOption {
      type = types.int;
      default = 65001;
      description = "Local BGP AS number";
    };

    remoteAS = mkOption {
      type = types.int;
      default = 65000;
      description = "Remote BGP AS number for uplink peer";
    };

    uplinkPeer = mkOption {
      type = types.str;
      default = "10.1.100.1";
      description = "IP address of the uplink BGP peer";
    };
  };

  config = mkIf cfg.enable {
    # Require cluster config to be available
    assertions = [
      {
        assertion = config.provisioning.clusterConfig.enable;
        message = "services.frr-bgp requires provisioning.clusterConfig.enable = true";
      }
    ];

    services.frr = {
      bgpd.enable = true;
    };

    # Override the static frr.conf with a mutable one
    environment.etc."frr/frr.conf" = mkForce {
      enable = false;  # Disable the static symlink
    };

    # Create log and config directories for frr
    systemd.tmpfiles.rules = [
      "d /var/log/frr 0755 frr frr -"
      "d /var/lib/frr 0755 frr frr -"
    ];

    # Open BGP port in firewall
    networking.firewall = mkIf config.networking.firewall.enable {
      allowedTCPPorts = [ 179 ];
    };

    # Generate FRR config at runtime with substituted values
    systemd.services.frr = {
      after = [ "provision-cluster-config.service" ];
      requires = [ "provision-cluster-config.service" ];

      preStart = ''
        # Source cluster config
        source /etc/default/cluster

        # Generate frr.conf with substituted values in /var/lib/frr
        cat > /var/lib/frr/frr.conf <<EOF
! FRR configuration
!
hostname $CLUSTER_HOSTNAME
log file /var/log/frr/frr.log debugging
log timestamp precision 3
service password-encryption
service integrated-vtysh-config
!
router bgp ${toString cfg.localAS}
  bgp router-id $CLUSTER_NODE_ADDRESS
  bgp log-neighbor-changes
  bgp graceful-shutdown
  no bgp default ipv4-unicast
  no bgp ebgp-requires-policy

  # Peer with upstream router
  neighbor uplink peer-group
  neighbor uplink remote-as ${toString cfg.remoteAS}
  neighbor ${cfg.uplinkPeer} peer-group uplink

  address-family ipv4 unicast
    redistribute connected
    neighbor uplink activate
    neighbor uplink allowas-in origin
    neighbor uplink prefix-list only-host-prefixes out
  exit-address-family
!

ip prefix-list only-default permit 0.0.0.0/0
ip prefix-list only-host-prefixes permit 0.0.0.0/0 ge 32

route-map rm-only-default permit 10
  match ip address prefix-list only-default
  set src $CLUSTER_NODE_ADDRESS

ip protocol bgp route-map rm-only-default

ip nht resolve-via-default
end
EOF

        # Create symlink from /etc/frr/frr.conf to our generated config
        ln -sf /var/lib/frr/frr.conf /etc/frr/frr.conf

        echo "Generated /var/lib/frr/frr.conf for node $CLUSTER_HOSTNAME with router-id $CLUSTER_NODE_ADDRESS"
      '';
    };
  };
}
