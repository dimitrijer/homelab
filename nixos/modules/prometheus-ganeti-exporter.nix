{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.prometheus.exporters.ganeti;
  settingsFormat = pkgs.formats.ini { };
in
{
  options.services.prometheus.exporters.ganeti = {
    enable = mkEnableOption "prometheus ganeti exporter";

    package = mkPackageOption pkgs "prometheus-ganeti-exporter" { };

    settings = mkOption {
      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          default = {
            port = mkOption { type = types.int; description = "port that prometheus-ganeti-exporter listens on"; default = 8000; };
            verify_tls = mkOption { type = types.bool; description = "check certificates when connecting"; default = false; };
            refresh_interval = mkOption { type = types.ints.positive; description = "refresh interval in seconds"; default = 10; };
          };
          ganeti = {
            api = mkOption { type = types.str; description = "full URL of RAPI endpoint"; default = "https://localhost:5080"; };
            user = mkOption { type = types.str; description = "Ganeti RAPI user"; default = "prometheus-ganeti-exporter"; };
            password = mkOption { type = types.str; description = "Ganeti RAPI passowrd"; default = "prometheus-ganeti-exporter"; };
          };
        };
      };
    };

    user = mkOption {
      type = types.str;
      default = "prometheus-ganeti-exporter";
      description = "User under which the exporter runs.";
    };

    group = mkOption {
      type = types.str;
      default = "prometheus-ganeti-exporter";
      description = "Group under which the exporter runs.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to open the TCP port in the firewall.";
    };
  };

  config = mkIf cfg.enable
    {
      users.users = mkIf (cfg.user == "prometheus-ganeti-exporter") {
        prometheus-ganeti-exporter = {
          inherit (cfg) group;
          isSystemUser = true;
        };
      };

      users.groups = mkIf (cfg.group == "prometheus-ganeti-exporter") {
        prometheus-ganeti-exporter = { };
      };

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.settings.default.port ];

      systemd.services."prometheus-ganeti-exporter" = mkIf cfg.enable {
        description = "Prometheus Ganeti Exporter";
        wants = [ "ganeti.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = ''
            ${lib.getExe cfg.package} --config ${settingsFormat.generate "prometheus-ganeti-exporter.ini" cfg.settings}
          '';
          User = cfg.user;
          Group = cfg.group;
          Restart = "always";
          ReadWritePaths = "";
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          PrivateDevices = true;
          PrivateUsers = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          RestrictRealtime = true;
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          UMask = "0066";
          ProtectHostname = true;
        };
      };
    };
}
