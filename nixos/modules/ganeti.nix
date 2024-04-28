{ config, pkgs, lib, modulesPath, ... }:

with lib;

let
  cfg = config.virtualisation.ganeti;
in
{
  imports = [
    (modulesPath + "/virtualisation/openvswitch.nix")
    ./provisioning/keys.nix
  ];

  options.virtualisation.ganeti = {
    enable = mkEnableOption "enable ganeti";
    clusterName = mkOption {
      type = types.str;
    };
    clusterAddress = mkOption {
      type = types.str;
      description = "floating IP address for the cluster";
    };
    domain = mkOption {
      type = types.str;
      description = "all nodes will be part of this domain";
    };
    nodes = mkOption {
      type = types.attrsOf
        (types.submodule {
          options = {
            hostname = mkOption { type = types.str; };
            address = mkOption { type = types.str; };
            rootPubkey = mkOption { type = types.str; };
            hostPubkey = mkOption { type = types.str; };
          };
        });
    };
    initialMasterNode = mkOption {
      type = types.enum (mapAttrsToList (name: node: name) cfg.nodes);
    };
    adminUsers = mkOption {
      type = types.listOf (types.enum (mapAttrsToList (name: user: name) config.users.users));
      default = [ ];
    };
    vgName = mkOption {
      type = types.str;
      default = "xenvg";
      description = "name of volume group to be used for Ganeti";
    };
    primaryInterface = mkOption {
      type = types.str;
      default = "eth0";
      description = "primary interface name (uplink)";
    };
    osProviders = mkOption {
      type = types.listOf types.package;
    };
  };

  config =
    let
      osProvidersPackage = pkgs.symlinkJoin {
        name = "os-providers";
        paths = cfg.osProviders;
      };
    in
    mkIf cfg.enable {
      virtualisation.vswitch.enable = true;
      networking = {
        useDHCP = false;
        vswitches = {
          br0.interfaces = {
            "${cfg.primaryInterface}" = {
              name = "${cfg.primaryInterface}";
            };
            gnt0 = {
              name = "gnt0";
              type = "internal";
            };
          };
        };
        interfaces = {
          "${cfg.primaryInterface}".useDHCP = false;
          gnt0.useDHCP = false;
          br0.useDHCP = true;
        };
        search = [ cfg.domain ];
        firewall = mkIf config.networking.firewall.enable {
          allowedTCPPorts = [
            5900 # vnc console
            1811 # gnt-noded
            5080 # gnt-rapi
          ];
          allowedTCPPortRanges = [
            {
              from = 7788;
              to = 65535;
            } # for drbd traffic and VNC console access
          ];
        };
        enableIPv6 = false;
        hosts = mkForce
          (
            let
              init =
                {
                  "127.0.0.1" = [ ]; # ganeti doesn't like localhost resolving to loopback addresses
                  "127.0.0.2" = [ ];
                  "${cfg.clusterAddress}" = [
                    "${cfg.clusterName}.${cfg.domain}"
                    "${cfg.clusterName}"
                  ];
                };
              nodesList = lib.attrsets.mapAttrsToList (name: value: value) cfg.nodes;
            in
            builtins.foldl'
              (acc: elem: acc // {
                "${elem.address}" = [
                  "${elem.hostname}.${cfg.domain}"
                  "${elem.hostname}"
                ];
              })
              init
              nodesList
          );
      };

      services.openssh = {
        settings.PermitRootLogin = "yes";
      };

      provisioning.keys.enable = true;
      provisioning.keys.wantedBy = [ "ganeti.target" "ganeti-node.target" ];

      users.users.root.openssh.authorizedKeys.keys = lib.attrsets.mapAttrsToList
        (name: node: node.rootPubkey)
        cfg.nodes;

      environment.systemPackages =
        let
          pubkeyList = lib.attrsets.mapAttrsToList
            (name: node: node.hostPubkey)
            cfg.nodes;
          knownHosts = concatLines
            pubkeyList;
          nodes =
            lib.attrsets.mapAttrsToList
              (name: node: {
                inherit name node;
              })
              cfg.nodes;
          nonMasterNodes = filter
            ({ name, node }: name != cfg.initialMasterNode)
            nodes;
          addNodesCmd = concatLines
            (map
              ({ name, node }:
                "echo \"Adding ${node.hostname} to cluster...\" && ${pkgs.ganeti.out}/bin/gnt-node add ${node.hostname}.${cfg.domain}")
              nonMasterNodes);
          setupClusterScript = pkgs.writeShellScriptBin
            "gnt-setup-cluster"
            ''
              set -eu -o pipefail
          
              this_node=$(hostname --fqdn)
              initial_master="${cfg.initialMasterNode}.${cfg.domain}" 
              if [ "$this_node" != "$initial_master" ]; then
                echo >&2 "This node ($this_node) is not the initial master node ($initial_master)."
                echo >&2 "Please run this script on the initial master node."
                exit 1
              fi
    
              ${pkgs.coreutils.out}/bin/mkdir -p \
                /var/lib/ganeti \
                /var/log/ganeti \
                /var/run/ganeti \
                /srv/ganeti

              echo "Running cluster init..."

              ${pkgs.ganeti.out}/bin/gnt-cluster init \
                  --enabled-hypervisors kvm \
                  --hypervisor-parameters 'kvm:kvm_flag=enabled,kernel_path=,initrd_path=,vnc_bind_address=0.0.0.0' \
                  --enabled-disk-templates drbd \
                  --disk-parameters 'drbd:metavg=${cfg.vgName}' \
                  --vg-name ${cfg.vgName} \
                  --nic-parameters 'mode=openvswitch,link=br0' \
                  --master-netdev gnt0 \
                  --no-etc-hosts \
                  --no-ssh-init \
                  --drbd-usermode-helper ${pkgs.coreutils.out}/bin/true \
                  ${cfg.clusterName}.${cfg.domain}

              echo "Configuring known hosts..."
              ${pkgs.gawk.out}/bin/awk \
                '{ print "${cfg.clusterName}.${cfg.domain} " $1 " " $2 }' \
                >/var/lib/ganeti/known_hosts <<EOF
              ${knownHosts}
              EOF

              ${addNodesCmd}
            '';
        in
        with pkgs;
        [
          drbd
          qemu
          lvm2
          ganeti
          setupClusterScript
          osProvidersPackage
        ];

      boot.kernelModules = [
        "kvm-intel"
        "drbd"
      ];
      boot.extraModprobeConfig = ''
        options drbd minor_count=128 usermode_helper=${pkgs.coreutils.out}/bin/true
      '';

      # User/group setup taken from tools/user-setup
      users.extraGroups = {
        "gnt-luxid" = { };
        "gnt-daemons" = { };
        "gnt-admin" = {
          members = cfg.adminUsers;
        };
        "gnt-confd" = { };
        "gnt-masterd" = { };
        "gnt-rapi" = { };
        "gnt-metad" = { };
      };

      users.extraUsers = {
        "gnt-masterd" = {
          isSystemUser = true;
          group = "gnt-masterd";
          extraGroups = [ "gnt-daemons" "gnt-admin" "gnt-confd" ];
        };
        "gnt-confd" = {
          isSystemUser = true;
          group = "gnt-confd";
          extraGroups = [ "gnt-daemons" ];
        };
        "gnt-rapi" = {
          isSystemUser = true;
          group = "gnt-rapi";
          extraGroups = [ "gnt-daemons" "gnt-admin" ];
        };
        "gnt-metad" = {
          isSystemUser = true;
          group = "gnt-metad";
          extraGroups = [ "gnt-daemons" ];
        };
      };
      systemd.targets =
        {
          "ganeti" = {
            description = "Ganeti virtualization cluster manager";
            documentation = [ "man:ganeti(7)" ];
            partOf = [ "ganeti.service" ];
            wantedBy = lib.mkForce [ ]; # loaded on request
          };
          "ganeti-node" = {
            description = "Ganeti node functionality";
            documentation = [ "man:ganeti(7)" ];
            after = [ "systemd-journald.service" "provision-keys.service" ]; # "syslog.service"
            partOf = [ "ganeti.target" ];
            wantedBy = [ "ganeti.target" ];
          };

          "ganeti-master" = {
            description = "Ganeti master functionality";
            documentation = [ "man:ganeti(7)" ];
            after = [ "systemd-journald.service" "provision-keys.service" ]; #"syslog.service"
            partOf = [ "ganeti.target" ];
            wantedBy = [ "ganeti.target" ];
          };
        };

      systemd.services = {
        "ganeti-common" = {
          description = "Ganeti one-off setup";
          serviceConfig =
            # TODO: read OS search path from 
            #/share/ganeti/3.0/ganeti/_constants.py:OS_SEARCH_PATH = ["/srv/ganeti/os"]
            let
              linkOsProviders = pkgs.writeShellScriptBin "link-os-providers" ''
                ${pkgs.coreutils.out}/bin/mkdir -p /srv/ganeti
                ${pkgs.coreutils.out}/bin/ln -sfT ${osProvidersPackage.out} /srv/ganeti/os
              '';
            in
            {
              Type = "oneshot";
              ExecStartPre = "${linkOsProviders}/bin/link-os-providers";
              ExecStart = "${pkgs.ganeti.out}/lib/ganeti/ensure-dirs";
            };
          # Disable start rate limit because ganeti-common.service is executed
          # multiple times from ganeti-*.service in ganeti.target.
          # Source: https://github.com/jfut/ganeti-rpm/blob/4f2f64532d65805aefe97296d541a14e2fe53bb1/rpmbuild/ganeti/SOURCES/ganeti-3.0.0-disable-start-rate-limit.patch
          startLimitBurst = 0;
          wantedBy = [ "multi-user.target" ]; # This service should run before setting up nodes.
        };

        "ganeti-luxid" = {
          description = "Ganeti query daemon (luxid)";
          documentation = [ "man:ganeti-luxid(8)" ];
          requires = [ "ganeti-common.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-master.target" ];
          unitConfig = {
            ConditionPathExists = [ "/var/lib/ganeti/config.data" ];
          };

          serviceConfig = {
            Type = "simple";
            User = "gnt-masterd";
            Group = "gnt-luxid";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-luxid.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-luxid -f $LUXID_ARGS $ONETIME_ARGS";
            Restart = "on-failure";
            SuccessExitStatus = [ 0 11 ];
          };
          wantedBy = [ "ganeti-master.target" "ganeti.target" ];
        };

        "ganeti-confd" = {
          description = "Ganeti configuration daemon (confd)";
          documentation = [ "man:ganeti-confd(8)" ];
          requires = [ "ganeti-common.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-node.target" ];
          unitConfig = {
            ConditionPathExists = [ "/var/lib/ganeti/config.data" ];
          };

          serviceConfig = {
            Type = "simple";
            User = "gnt-confd";
            Group = "gnt-confd";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-confd.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-confd -f $CONFD_ARGS $ONETIME_ARGS";
            Restart = "on-failure";
          };
          wantedBy = [ "ganeti-node.target" "ganeti.target" ];
        };

        "ganeti-kvmd" = {
          description = "Ganeti KVM daemon (kvmd)";
          documentation = [ "man:ganeti-kvmd(8)" ];
          requires = [ "ganeti-common.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-node.target" ];

          serviceConfig = {
            Type = "simple";
            Group = "gnt-daemons";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-kvmd.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-kvmd -f $KVMD_ARGS $ONETIME_ARGS";
            Restart = "on-failure";
          };
          wantedBy = [ "ganeti-node.target" "ganeti.target" ];
        };

        "ganeti-metad" = {
          description = "Ganeti instance metadata daemon (metad)";
          requires = [ "ganeti-common.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-node.target" ];

          serviceConfig = {
            Type = "simple";
            User = "gnt-metad";
            Group = "gnt-metad";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-metad.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-metad -f $METAD_ARGS $ONETIME_ARGS";
            Restart = "on-failure";
            CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
            AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          };
          # ganeti-metad is started on-demand by noded, so there must be no Install
          # section.
        };

        "ganeti-mond" = {
          description = "Ganeti monitoring daemon (mond)";
          documentation = [ "man:ganeti-mond(8)" ];
          requires = [ "ganeti-common.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-node.target" ];

          serviceConfig = {
            Type = "simple";
            User = "root";
            Group = "root";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-mond.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-mond -f $MOND_ARGS $ONETIME_ARGS";
            Restart = "on-failure";
          };
          wantedBy = [ "ganeti-node.target" "ganeti.target" ];
        };

        "ganeti-rapi" = {
          description = "Ganeti RAPI daemon (rapi)";
          documentation = [ "man:ganeti-rapi(8)" ];
          requires = [ "ganeti-common.service" ];
          requisite = [ "ganeti-luxid.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-master.target" ];
          unitConfig = {
            ConditionPathExists = [ "/var/lib/ganeti/rapi.pem" ];
          };

          serviceConfig = {
            Type = "simple";
            User = "gnt-rapi";
            Group = "gnt-rapi";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-rapi.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-rapi -f $RAPI_ARGS $ONETIME_ARGS";
            SuccessExitStatus = [ 0 11 ];
            Restart = "on-failure";
          };
          wantedBy = [ "ganeti-master.target" "ganeti.target" ];
        };

        "ganeti-wconfd" = {
          description = "Ganeti config writer daemon (wconfd)";
          documentation = [ "man:ganeti-wconfd(8)" ];
          requires = [ "ganeti-common.service" ];
          after = [ "ganeti-common.service" ];
          partOf = [ "ganeti-master.target" ];
          unitConfig = {
            ConditionPathExists = [ "/var/lib/ganeti/config.data" ];
          };

          serviceConfig = {
            Type = "simple";
            User = "gnt-masterd";
            Group = "gnt-confd";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-wconfd.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-wconfd -f $WCONFD_ARGS $ONETIME_ARGS";
            SuccessExitStatus = [ 0 11 ];
            Restart = "on-failure";
          };
          wantedBy = [ "ganeti-master.target" "ganeti.target" ];
        };

        "ganeti-noded" = {
          description = "Ganeti node daemon (noded)";
          documentation = [ "man:ganeti-noded(8)" ];
          after = [ "ganeti-common.service" ];
          requires = [ "ganeti-common.service" ];
          partOf = [ "ganeti-node.target" ];
          unitConfig = {
            ConditionPathExists = [ "/var/lib/ganeti/server.pem" ];
          };
          wantedBy = [ "ganeti-node.target" "ganeti.target" ];

          serviceConfig = {
            Type = "simple";
            User = "root";
            Group = "root";
            EnvironmentFile = [ "-${pkgs.ganeti.out}/etc/default/ganeti" "-/var/lib/ganeti/ganeti-noded.onetime.conf" ];
            ExecStart = "${pkgs.ganeti.out}/sbin/ganeti-noded -f $NODED_ARGS $ONETIME_ARGS";
            Restart = "on-failure";
            # Important: do not kill any KVM processes
            KillMode = "process";
          };
        };
      };
    };
}
