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

    withNorthd = mkOption {
      type = types.bool;
      description = "whether to run ovn northd daemon";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.vswitch.enable = true;
    virtualisation.vswitch.package = pkgs.ovn;
    environment.systemPackages = [ pkgs.ovn ];

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

      "ovn-northd" = mkIf cfg.withNorthd {
        description = "OVN northd management daemon";

        serviceConfig =
          {
            Type = "oneshot";
            RemainAfterExit = "yes";
            Environment = "OVN_RUNDIR=%t/ovn OVN_DBDIR=/var/lib/ovn";
            ExecStartPre = "${pkgs.coreutils.out}/bin/mkdir -p /var/lib/ovn";
            ExecStart = "${pkgs.ovn.out}/share/ovn/scripts/ovn-ctl start_northd";
            ExecStop = "${pkgs.ovn.out}/share/ovn/scripts/ovn-ctl stop_northd";
          };

        wantedBy = [ "multi-user.target" ];
      };
    };
  };

}
