{ config, pkgs, lib, modulesPath, ... }:

with lib;

let
  cfg = config.virtualisation.ganeti;
in
{
  imports = [
    (modulesPath + "/virtualisation/openvswitch.nix")
  ];

  options.virtualisation.ganeti = {
    enable = mkEnableOption "enable ganeti";
    clusterName = mkOption {
      type = types.str;
    };
    clusterAddress = mkOption {
      type = types.str;
    };
    domain = mkOption {
      type = types.str;
    };
    nodes = mkOption {
      type = types.listOf (types.submodule {
        options = {
          hostname = mkOption { type = types.str; };
          address = mkOption { type = types.str; };
        };
      });
      default = [ ];
    };
    adminUsers = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    virtualisation.vswitch.enable = true;
    networking.firewall = lib.mkIf config.networking.firewall.enable {
      allowedTCPPorts = [
        5900 # vnc console
      ];
    };

    networking.hosts = mkForce
      (
        let
          init =
            {
              "127.0.0.1" = [ ]; # ganeti doesn't like localhost resolving to loopback addresses
              "127.0.0.2" = [ ];
              "${cfg.clusterAddress}" = [
                "${cfg.clusterName}"
                "${cfg.clusterName}.${cfg.domain}"
              ];
            };
        in
        builtins.foldl'
          (acc: elem: acc // {
            "${elem.address}" = [
              "${elem.hostname}"
              "${elem.hostname}.${cfg.domain}"
            ];
          })
          init
          cfg.nodes
      );

    environment.systemPackages = with pkgs;
      [
        drbd
        qemu
        ganeti
      ];

    boot.kernelModules = [
      "kvm-intel"
    ];

    users.extraGroups = {
      "gnt-luxid" = { };
      "gnt-daemons" = { };
      "gnt-admin" = {
        members = cfg.adminUsers;
      };
    };

    users.extraUsers = {
      "gnt-masterd" = {
        isSystemUser = true;
        group = "gnt-masterd";
        extraGroups = [ "gnt-daemons" ];
      };
      "gnt-confd" = {
        isSystemUser = true;
        group = "gnt-confd";
        extraGroups = [ "gnt-daemons" ];
      };
      "gnt-rapi" = {
        isSystemUser = true;
        group = "gnt-rapi";
        extraGroups = [ "gnt-daemons" ];
      };
    };
  };
}
