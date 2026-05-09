{ pkgs, config, lib, modulesPath, ... }:

with lib;

let
  cfg = config.services.nomad;

  pluginDir = pkgs.linkFarm "nomad-plugins" (
    optional (cfg.driverVirtPackage != null) {
      name = "nomad-driver-virt";
      path = "${cfg.driverVirtPackage}/bin/nomad-driver-virt";
    }
  );

  nodeAddresses = mapAttrsToList (_: node: ''"${node.address}"'') config.virtualisation.ganeti.nodes;

  driverVirtConfig = optionalString (cfg.driverVirtPackage != null) ''

    plugin "nomad-driver-virt" {
      config {
        emulator {
          uri = "qemu:///system"
        }
        ${optionalString (cfg.sharedDataDir != null) ''
        shared_data_dir = "${cfg.sharedDataDir}"
        ''}
        ${optionalString (cfg.ovnNBConnection != null) ''
        ovn {
          nb_connection = "${cfg.ovnNBConnection}"
        }
        ''}
      }
    }
  '';

  baseConfig = pkgs.writeText "nomad-base.hcl" ''
    datacenter = "${cfg.datacenter}"
    region     = "${cfg.region}"
    data_dir   = "/var/lib/nomad"
    plugin_dir = "${pluginDir}"

    server {
      enabled          = ${boolToString cfg.serverEnabled}
      bootstrap_expect = ${toString cfg.bootstrapExpect}

      server_join {
        retry_join = [${concatStringsSep ", " nodeAddresses}]
      }
    }

    client {
      enabled  = ${boolToString cfg.clientEnabled}
      cni_path = "${pkgs.cni-plugins}/bin"
    }
    ${driverVirtConfig}
  '';
in
{
  disabledModules = [
    (modulesPath + "/services/networking/nomad.nix")
  ];

  options.services.nomad = {
    enable = mkEnableOption "Nomad agent";

    package = mkOption {
      type = types.package;
      default = pkgs.nomad;
      description = "Nomad package to use";
    };

    driverVirtPackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "nomad-driver-virt package; enables libvirt when set";
    };

    serverEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Nomad server mode";
    };

    clientEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Nomad client mode";
    };

    bootstrapExpect = mkOption {
      type = types.int;
      default = 3;
      description = "Number of servers to expect for bootstrap (should be odd)";
    };

    datacenter = mkOption {
      type = types.str;
      default = "dc1";
      description = "Nomad datacenter name";
    };

    region = mkOption {
      type = types.str;
      default = "global";
      description = "Nomad region name";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open firewall ports for Nomad";
    };

    ovnNBConnection = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "OVN northbound database connection string (e.g. tcp:10.1.100.5:6641)";
    };

    nfsImageStore = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "NFS server path for shared VM storage (e.g. 10.1.100.1:/export/virt)";
    };

    sharedDataDir = mkOption {
      type = types.nullOr types.str;
      default = if cfg.nfsImageStore != null then "/var/lib/virt-shared" else null;
      description = "Local mount point for shared NFS storage; set automatically when nfsImageStore is configured";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.provisioning.clusterConfig.enable;
        message = "services.nomad requires provisioning.clusterConfig.enable = true";
      }
    ];

    # Enable libvirt when the virt driver is configured
    virtualisation.ganeti.libvirtEnabled = mkIf (cfg.driverVirtPackage != null) true;

    # Nomad hardcodes /sbin/ip for network fingerprinting
    system.activationScripts.nomad-ip-symlink = ''
      mkdir -p /sbin
      ln -sfn ${pkgs.iproute2}/bin/ip /sbin/ip
    '';

    environment.etc."nomad.d/base.hcl".source = baseConfig;

    # Mount NFS share for shared VM storage
    boot.supportedFilesystems = mkIf (cfg.nfsImageStore != null) [ "nfs" ];

    fileSystems = mkIf (cfg.nfsImageStore != null) {
      "${cfg.sharedDataDir}" = {
        device = cfg.nfsImageStore;
        fsType = "nfs";
        # _netdev tells systemd-fstab-generator this is a network mount.
        # We explicitly depend on stage 2's systemd-networkd-wait-online
        # rather than network-online.target because the latter is activated
        # in initrd (by netboot-fetch-store), inherited as already-active by
        # stage 2 systemd, and therefore satisfies Requires= vacuously —
        # before stage 2 networkd has even started bringing up br0. With
        # br0 carrying RequiredForOnline=routable, waiting on stage 2's
        # wait-online ensures DHCPv4 + default route are in place before
        # mount.nfs tries to reach 192.168.87.1.
        options = [
          "nfsvers=4"
          "soft"
          "timeo=30"
          "_netdev"
          "x-systemd.requires=systemd-networkd-wait-online.service"
          "x-systemd.after=systemd-networkd-wait-online.service"
        ];
      };
    };

    # Generate runtime config with advertise addresses from cluster config
    systemd.services.nomad-config = {
      description = "Generate Nomad runtime configuration";
      after = [ "provision-cluster-config.service" ];
      requires = [ "provision-cluster-config.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        source /etc/default/cluster

        mkdir -p /var/lib/nomad
        cat > /var/lib/nomad/runtime.hcl <<EOF
        name = "$CLUSTER_HOSTNAME"

        advertise {
          http = "$CLUSTER_NODE_ADDRESS"
          rpc  = "$CLUSTER_NODE_ADDRESS"
          serf = "$CLUSTER_NODE_ADDRESS"
        }
        EOF

        echo "Generated /var/lib/nomad/runtime.hcl for $CLUSTER_HOSTNAME ($CLUSTER_NODE_ADDRESS)"
      '';

      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.nomad = {
      description = "HashiCorp Nomad Agent";
      after = [ "nomad-config.service" "network-online.target" ];
      requires = [ "nomad-config.service" ];
      wants = [ "network-online.target" ];

      # nomad-driver-virt needs iptables for VM network setup;
      # iproute2 needed for network fingerprinting;
      # qemu-utils needed for qemu-img (blank disk creation)
      path = with pkgs; [ iptables iproute2 qemu-utils ovn ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/nomad agent -config=/etc/nomad.d -config=/var/lib/nomad/runtime.hcl";
        KillMode = "process";
        LimitNOFILE = 65536;
        Restart = "on-failure";
      } // optionalAttrs (cfg.nfsImageStore != null) {
        RequiresMountsFor = cfg.sharedDataDir;
      };

      wantedBy = [ "multi-user.target" ];
    };

    boot.kernelModules = [ "bridge" ];

    networking.firewall = mkIf (cfg.openFirewall && config.networking.firewall.enable) {
      allowedTCPPorts = [
        4646  # HTTP API
        4647  # RPC
        4648  # Serf
      ];
      allowedUDPPorts = [
        4648  # Serf
      ];
    };

    environment.systemPackages = [
      cfg.package
      pkgs.cni-plugins
    ];
  };
}
