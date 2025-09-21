{ config, pkgs, lib, modulesPath, ... }:

with lib;

let
  cfg = config.virtualisation.ovn;
in
{
  imports = [
    (modulesPath + "/virtualisation/openvswitch.nix")
  ];

  options.virtualisation.ovn = {
    enable = mkEnableOption "enable ovn";

    openFirewall = mkOption {
      type = types.bool;
      description = "whether to open firewall ports for geneve, nb and sb ovs databases";
      default = false;
    };
  };

  config = mkIf cfg.enable {
    virtualisation.vswitch.enable = true;
    virtualisation.vswitch.package = pkgs.ovn;
    environment.systemPackages = [ pkgs.ovn ];

    networking.firewall = mkIf config.networking.firewall.enable {
      allowedUDPPorts = mkIf cfg.openFirewall [
        6081 # geneve tunnel
      ];
      allowedTCPPorts = mkIf cfg.openFirewall [
        6642 # sb db
        6641 # nb db
      ];
    };

    systemd.services = {
      "ovn-controller" = {
        description = "OVN controller daemon";
        requires = [ "ovs-vswitchd.service" ];
        after = [ "ovs-vswitchd.service" ];

        serviceConfig =
          {
            Type = "forking";
            PIDFile = "/run/ovn/ovn-controller.pid";
            Restart = "on-failure";
            Environment = "OVN_RUNDIR=%t/ovn OVS_RUNDIR=%t/openvswitch";
            ExecStart = "${pkgs.ovn.out}/share/ovn/scripts/ovn-ctl --no-monitor start_controller";
            ExecStop = "${pkgs.ovn.out}/share/ovn/scripts/ovn-ctl stop_controller";
          };

        wantedBy = [ "multi-user.target" ];
      };

      "ovn-northd" = {
        description = "OVN northd management daemon";

        serviceConfig =
          {
            Type = "oneshot";
            RemainAfterExit = "yes";
            Environment = "OVN_RUNDIR=%t/ovn OVN_DBDIR=/var/lib/ovn";
            ExecStartPre = "${pkgs.coreutils.out}/bin/mkdir -p /var/lib/ovn";
            ExecStart = "${pkgs.ovn.out}/share/ovn/scripts/ovn-ctl start_northd --db-sb-create-insecure-remote=yes --db-nb-create-insecure-remote=yes";
            ExecStop = "${pkgs.ovn.out}/share/ovn/scripts/ovn-ctl stop_northd";
          };

        wantedBy = [ "multi-user.target" ];
      };
    };
  };

}
