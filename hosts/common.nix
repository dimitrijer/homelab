{ pkgs
, config
}:

{
  console.keyMap = "us";

  users.users.dimitrije =
    {
      isNormalUser = true;
      home = "/home/dimitrije";
      description = "Dimitrije Radojevic";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJklWVMXaRPHb2+px018aQdEldAtzt9+MZHqImMmDFZa dimitrije@prospect" ];
    };
  users.users.root.initialHashedPassword = "$y$j9T$gChWZEYyiVSALFhhHwI39.$UrwTZVYmKMvUp9tQbcTpaNeYKI7w3uRyZ3KcgqnxcK1";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 5900 ];
  };

  system.stateVersion = config.system.nixos.release;

  boot.kernelParams = [
    "console=tty0"
    "console=ttyS1,19200" # serial over LAN
    "apm=off"
    "pcie_aspm=off"
  ];

  boot.kernelModules = [
    "kvm-intel"
  ];

  systemd.services."serial-getty@ttyS1" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    serviceConfig.Restart = "always";
  };

  services.openssh = {
    enable = true;
  };

  services.fwupd.enable = true;
  disko = {
    enableConfig = false;
    devices = {
      disk = {
        ssd = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "table";
            format = "gpt";
            partitions = [
              {
                name = "ESP";
                start = "1M";
                end = "100M";
                bootable = true;
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              }
              {
                name = "lvm_pv";
                start = "100M";
                end = "100%";
                content = {
                  type = "lvm_pv";
                  vg = "pool_gnt";
                };
              }
            ];
          };
        };
        hdd = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "table";
            format = "gpt";
            partitions = [
              {
                name = "lvm_pv";
                start = "1M";
                end = "100%";
                content = {
                  type = "lvm_pv";
                  vg = "pool_host";
                };
              }
            ];
          };
        };
      };

      lvm_vg = {
        pool_host = {
          type = "lvm_vg";
          lvs = {
            root = {
              size = "40G";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/";
              };
            };
            home = {
              size = "100%FREE";
              content = {
                type = "filesystem";
                format = "xfs";
                mountpoint = "/home";
              };
            };
          };
        };

        pool_gnt = {
          type = "lvm_vg";
          lvs = { };
        };
      };
    };
  };

  environment.systemPackages = with pkgs;
    [
      (writeShellScriptBin "disko-fmt" "${config.system.build.formatScript}")
      (writeShellScriptBin "disko-mnt" "${config.system.build.mountScript}")
      python3
      git
      ethtool
      iperf3
      telnet
      netcat
      drbd
      qemu
      ganeti
    ];
}
