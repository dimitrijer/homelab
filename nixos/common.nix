{ pkgs, config, lib, modulesPath, ... }:

let
  hddDevice = "/dev/sda";
  nvmeDevice = "/dev/nvme0n1";
  vgGaneti = "pool_gnt";
  vgHost = "pool_host";
  disko-fmt = pkgs.writeShellScriptBin "disko-fmt" "${config.system.build.formatScript}";
  disko-mnt = pkgs.writeShellScriptBin "disko-mnt" "${config.system.build.mountScript}";
in
{
  imports = [ ./ganeti.nix ];
  config =
    {
      # Will be provided via kernel cmdline.
      networking.hostName = lib.mkForce "";
      console.keyMap = "us";
      time.timeZone = "Europe/London";

      users.users.dimitrije =
        {
          isNormalUser = true;
          home = "/home/dimitrije";
          description = "Dimitrije Radojevic";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJklWVMXaRPHb2+px018aQdEldAtzt9+MZHqImMmDFZa dimitrije@prospect" ];
        };

      users.users.root.initialHashedPassword = "$y$j9T$gChWZEYyiVSALFhhHwI39.$UrwTZVYmKMvUp9tQbcTpaNeYKI7w3uRyZ3KcgqnxcK1";

      security.sudo = {
        enable = true;
        extraRules = [{
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
          groups = [ "wheel" ];
        }];
      };

      virtualisation.ganeti = {
        enable = true;
        clusterAddress = "10.1.100.254";
        clusterName = "gnt";
        adminUsers = [ "dimitrije" ];
        primaryInterface = "enp0s31f6";
        domain = "homelab";
        vgName = vgGaneti;
        nodes = {
          aleph = {
            hostname = "aleph";
            address = "10.1.100.2";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOqtQEoaaBRfHYvYg12Au/3kaAD9T0qj7ZoMS4FbeLCl root@aleph";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6L0dpLZuQf8EV9tTM11HQOUZWn9QlOWlbZlsgaVGnesLf/Ct97o9nCyyn9QKC/ip2tl41SioVUdVv3lo86XOzaie2e3yR9rn4Ja71VAlvvx87yqF0yPruSHp/JB9V4gM20T8G/jp+n/sevE6FmmLvAn9vRLvTn/jUC0f2K8n76ZqgFewCoMYH6gYeKy173OWSFlt3+sPIVuRNlIY2GzajIYH0xMTZyQxFX6W2vrEb91igs/7uRfR95PDIKBqMjqCIiVyedGupHfB6hq3YsSxmquuaTL3wbd94LMjuqBM+TWPXv/h3ZV9Xdl8DYta28+nLhBT7PhD8rKnH13OlkLvlfvwzEL0IzOhQvN2DLcZC/us4ZmI3/Ytwc25pFmu9F9PHqhGtQQLlZD2SxI8ByhmvAglCkUFSdLrMvXetseUPB2JdZFq3T4j2jP39xCkMMKFwVaiGBlmAaamwNHYjI7NlG98YKpsMWUQfsOuCywc+u0swiI0lEawACqi2rsjymnM= root@aleph";
          };
          bet = {
            hostname = "bet";
            address = "10.1.100.3";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILTEnva103xW9Gj4bAdSSdZl7oS0y7v7ESPxULALgtCk root@bet";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDF41n7atbOWgI8y4cdpydMjjE9IbBX/09Qr8xQIxpw6AW/v65k3xpxnbgGTLeJSXhsvH2noB/R6cPzwWnb2FASNTDoI5HALe1gHDV62IulNTdnU621SpPN+F8TW7OylY1Jv+aU1p8tsm876oiqi+jq5OonInOZVLhi8fn0BWZBmDufPkwpmXqfWkzkiQpVvRWQGvTgiVV7BE8GmqgaAiaOOQyx+ruihoYtg7vB4sa5kiiK9v/TQd0xTC/9OBZxKDvEyYWHzDT3XJf9A9SxSq7GezKI6/m2/t/Y5Kv8kk5Gavbzlt8Qi+xAuh//g+79sXZh7vpvCSpVrJ8Pw3isSRGBo4qn5vtnwFstwO3XRxVuzFffjG8E/GNYSXtb2chbQMZewaxix/r41uriVDfuIdg7oEbkk9wnA+Oc1ndOWOLNvWTVLEJfiMjNv71+cJGzjJV0DvevDlwTWiOM31Od9QHursmG59Loj1mpI//R9mYkx8d1HlaKwhOPSfVmlTAs1l0= root@bet";
          };
          #gimel = {
          #  hostname = "gimel";
          #  address = "10.1.100.4";
          #};
          dalet = {
            hostname = "dalet";
            address = "10.1.100.5";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE7Fz1SlS9668sMah8PLib8FDGn82jT7ZAZ8CE1o8uYE root@dalet";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZIULso5QcqBb+4e/T5b/QDrE+nsbXSXWEgFFs/V+NjQK9lmDff/jBMkjuTWJVa2FQf8yOO1B6H+KbCKpDIrBlmJRhgKa1WNzfW33l8RRlFw7MRCx+uUdPBNW1IYhLbGyACbIAJIN5s0F809eVOCEvxhchU14NtRde/n2rMOVDhgxnUgU1DEOw7yh2lyqqPK0076bOYpAgEkPKnwI3Nvnxk8uECeRA7oQrUPtkayNdTvvRJSm9EDDi51aSjJc58GJizpAFyF7ahvXe8v7GO8mGls8k1euIykOIrGqjKh7OGZQWQCL1YLaMiBKyEtxBFb5eMa/ZAWAArW7YOuUHsIFjs8K6dzUKRe4pKg43TjWOPPUaTQzmlprcprAlNFuC1E9bVscYMd3OxBV9AGKVgbqihcgljogxQXVI5H4aTZPF7f5n7/JGdw6JilK1RH5zKYr7F8VBRMstdF8F4Q0XM+cl7VArdCHAInpdrpt5cMGFVz/MAZIaXuUOpoUMB1xR4tE= root@dalet";
          };
        };
        initialMasterNode = "aleph";
        osProviders = [ pkgs.ganeti-os-pxe ];
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 22 ];
      };

      networking.enableIPv6 = false;
      system.stateVersion = config.system.nixos.release;

      boot.kernelParams = [
        "console=tty0"
        "console=ttyS1,19200" # serial over LAN
        "apm=off"
        "pcie_aspm=off"
      ];

      systemd.services."serial-getty@ttyS1" = {
        enable = true;
        wantedBy = [ "getty.target" ];
        serviceConfig.Restart = "always";
      };

      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      documentation = {
        enable = true;
        man = {
          generateCaches = false;
          enable = true;
        };
        dev = {
          enable = true;
        };
      };

      services.fwupd.enable = true;
      disko = {
        # Do not override config.filesystems etc. using disko config.
        enableConfig = false;
        rootMountPoint = "/";
        devices = {
          disk = {
            ssd = {
              device = nvmeDevice;
              type = "disk";
              name = "ssd";
              content = {
                type = "lvm_pv";
                vg = vgGaneti;
              };
            };
            hdd = {
              device = hddDevice;
              type = "disk";
              name = "hdd";
              content = {
                type = "gpt";
                partitions = {
                  # EFI system partition cannot be a LV
                  ESP = {
                    type = "EF00";
                    start = "1M";
                    end = "100M";
                    content = {
                      type = "filesystem";
                      format = "vfat";
                      mountpoint = "/boot";
                    };
                  };
                  pool_host = {
                    size = "100%";
                    content = {
                      type = "lvm_pv";
                      vg = vgHost;
                    };
                  };
                };
              };
            };
          };

          lvm_vg = {
            "${vgHost}" = {
              type = "lvm_vg";
              lvs = {
                swap = {
                  size = "32G";
                  content = {
                    type = "swap";
                  };
                };
                home = {
                  size = "100G";
                  content = {
                    type = "filesystem";
                    format = "xfs";
                    mountpoint = "/home";
                  };
                };
                var = {
                  size = "100%FREE";
                  content = {
                    type = "filesystem";
                    format = "xfs";
                    mountpoint = "/var";
                  };
                };
              };
            };

            "${vgGaneti}" = {
              type = "lvm_vg";
              lvs = { };
            };
          };
        };
      };

      systemd.services."provision-disks" = {
        description = "Provision and/or mount disks";
        before = [ "local-fs.target" ];
        wants = [ "local-fs-pre.target" ];
        after = [ "local-fs-pre.target" ];

        path = with pkgs; [ coreutils util-linux lvm2 disko-fmt disko-mnt ];
        script = ''
          set -eu -o pipefail

          if ! vgs ${vgGaneti} ${vgHost} -o name --noheadings 2>&1 >/dev/null
          then
            for vg in $(vgs --noheadings -o name --rows)
            do
              echo "Removing VG $vg..."
              vgremove -f -y "$vg"
            done

            for pv in $(pvs --noheadings -o name --rows)
            do
              echo "Removing PV $pv..."
              pvremove -f "$pv"
            done

            echo "Wiping disks..."
            wipefs -a ${hddDevice}
            wipefs -a ${nvmeDevice}

            echo "Provisioning disks..."
            ${disko-fmt.out}/bin/disko-fmt
          fi

          echo "Mounting local disks..."
          ${disko-mnt.out}/bin/disko-mnt
        '';

        unitConfig = {
          DefaultDependencies = "no";
        };
        serviceConfig = {
          Type = "oneshot";
        };
        requiredBy = [ "local-fs.target" ];
      };
      environment.systemPackages = with pkgs;
        [
          disko-fmt
          disko-mnt
          python3
          git
          ethtool
          iperf3
          #inetutils
          netcat
          linux-manual
          man-pages
          man-pages-posix
          dig
          vim
        ];

    };
}
