{ pkgs, config, lib, modulesPath, ... }:

with lib;

let
  hddDevice = "/dev/sda";
  nvmeDevice = "/dev/nvme0n1";
  vgGaneti = "pool_gnt";
  vgHost = "pool_host";
  prometheusExporterUser = {
    user = "prometheus-ganeti-exporter";
    password = "0274833ae7ceb9be03abae36726ed487";
  };
in
{
  imports = [
    ../modules/common.nix
    ../modules/provisioning/disks.nix
    ../modules/cluster-config.nix
    ../modules/ganeti.nix
    ../modules/ovn.nix
    ../modules/frr.nix
    ../modules/prometheus-ganeti-exporter.nix
    ../modules/ovn-bgp-agent.nix
  ];

  config =
    {
      virtualisation.ganeti = {
        enable = true;
        clusterAddress = "10.1.100.254";
        clusterName = "gnt";
        adminUsers = [ "dimitrije" ];
        primaryInterface = "enp0s31f6";
        secondaryInterface = "enp3s0";
        domain = "homelab.tel";
        vgName = vgGaneti;
        nodes = {
          aleph = {
            hostname = "aleph";
            address = "10.1.100.2";
            secondaryAddress = "10.1.97.2";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOqtQEoaaBRfHYvYg12Au/3kaAD9T0qj7ZoMS4FbeLCl root@aleph";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC6L0dpLZuQf8EV9tTM11HQOUZWn9QlOWlbZlsgaVGnesLf/Ct97o9nCyyn9QKC/ip2tl41SioVUdVv3lo86XOzaie2e3yR9rn4Ja71VAlvvx87yqF0yPruSHp/JB9V4gM20T8G/jp+n/sevE6FmmLvAn9vRLvTn/jUC0f2K8n76ZqgFewCoMYH6gYeKy173OWSFlt3+sPIVuRNlIY2GzajIYH0xMTZyQxFX6W2vrEb91igs/7uRfR95PDIKBqMjqCIiVyedGupHfB6hq3YsSxmquuaTL3wbd94LMjuqBM+TWPXv/h3ZV9Xdl8DYta28+nLhBT7PhD8rKnH13OlkLvlfvwzEL0IzOhQvN2DLcZC/us4ZmI3/Ytwc25pFmu9F9PHqhGtQQLlZD2SxI8ByhmvAglCkUFSdLrMvXetseUPB2JdZFq3T4j2jP39xCkMMKFwVaiGBlmAaamwNHYjI7NlG98YKpsMWUQfsOuCywc+u0swiI0lEawACqi2rsjymnM= root@aleph";
          };
          bet = {
            hostname = "bet";
            address = "10.1.100.3";
            secondaryAddress = "10.1.97.3";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILTEnva103xW9Gj4bAdSSdZl7oS0y7v7ESPxULALgtCk root@bet";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDF41n7atbOWgI8y4cdpydMjjE9IbBX/09Qr8xQIxpw6AW/v65k3xpxnbgGTLeJSXhsvH2noB/R6cPzwWnb2FASNTDoI5HALe1gHDV62IulNTdnU621SpPN+F8TW7OylY1Jv+aU1p8tsm876oiqi+jq5OonInOZVLhi8fn0BWZBmDufPkwpmXqfWkzkiQpVvRWQGvTgiVV7BE8GmqgaAiaOOQyx+ruihoYtg7vB4sa5kiiK9v/TQd0xTC/9OBZxKDvEyYWHzDT3XJf9A9SxSq7GezKI6/m2/t/Y5Kv8kk5Gavbzlt8Qi+xAuh//g+79sXZh7vpvCSpVrJ8Pw3isSRGBo4qn5vtnwFstwO3XRxVuzFffjG8E/GNYSXtb2chbQMZewaxix/r41uriVDfuIdg7oEbkk9wnA+Oc1ndOWOLNvWTVLEJfiMjNv71+cJGzjJV0DvevDlwTWiOM31Od9QHursmG59Loj1mpI//R9mYkx8d1HlaKwhOPSfVmlTAs1l0= root@bet";
          };
          gimel = {
            hostname = "gimel";
            address = "10.1.100.4";
            secondaryAddress = "10.1.97.4";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINrL3dRr8biE95lKieFv1aU1veYPUE8emHM6KGzkvT6I root@gimel";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDa3Eie2lEFCnC6vIEU/UPKx1MvADaPZMCENB4uEquOaFiomyAqCda7c9p7te0hWPh+SsASNGGOH7BaOrCYARopl0TnSjHtRqkmtjAFsP3ciMFlAMmkd/zAb4JK0uJMyyA/STprNrK+20BD/sIfafEC6rA2QxKfYAdnW95X58VIXJ56yZgVy3Kkd6U0G0b4GcoZhR+pq4y3JxnB8MuZsSXDlfFXAXIutt63hVm6PhbT6I+uwU8aHevOusjC3F8ZVPDUWZPQm/KOOPINnEtC/UTLslbmROsah3L9G2otPi6cV19MIZzrq/rk0q1TFMJp8piroxPEF/r8uxoE0ODvn9U8P37ih+UyQCuykjSdyMskp25yswy2r5ftgv+hlqrTCjFyPjM24POtjjj/vB5Zbf47KfO/+822nnsZbTyieKi2wSxv48pvUFkcSdHJCvk6dOVJ5Kt0CW376J8CcDpNw+WHZyBqNcOXDzy1dkurYfaSCmRVGDNSSSf9FhihE2u74Yk= root@gimel";
          };
          dalet = {
            hostname = "dalet";
            address = "10.1.100.5";
            secondaryAddress = "10.1.97.5";
            rootPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE7Fz1SlS9668sMah8PLib8FDGn82jT7ZAZ8CE1o8uYE root@dalet";
            hostPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDZIULso5QcqBb+4e/T5b/QDrE+nsbXSXWEgFFs/V+NjQK9lmDff/jBMkjuTWJVa2FQf8yOO1B6H+KbCKpDIrBlmJRhgKa1WNzfW33l8RRlFw7MRCx+uUdPBNW1IYhLbGyACbIAJIN5s0F809eVOCEvxhchU14NtRde/n2rMOVDhgxnUgU1DEOw7yh2lyqqPK0076bOYpAgEkPKnwI3Nvnxk8uECeRA7oQrUPtkayNdTvvRJSm9EDDi51aSjJc58GJizpAFyF7ahvXe8v7GO8mGls8k1euIykOIrGqjKh7OGZQWQCL1YLaMiBKyEtxBFb5eMa/ZAWAArW7YOuUHsIFjs8K6dzUKRe4pKg43TjWOPPUaTQzmlprcprAlNFuC1E9bVscYMd3OxBV9AGKVgbqihcgljogxQXVI5H4aTZPF7f5n7/JGdw6JilK1RH5zKYr7F8VBRMstdF8F4Q0XM+cl7VArdCHAInpdrpt5cMGFVz/MAZIaXuUOpoUMB1xR4tE= root@dalet";
          };
        };
        initialMasterNode = "aleph";
        osProviders = [ pkgs.ganeti-os-pxe ];
        rapiUsers = [
          {
            inherit (prometheusExporterUser) user password;
            readonly = true;
          }
        ];
      };

      provisioning.clusterConfig.enable = true;

      virtualisation.ovn = {
        enable = true;
        openFirewall = true;
      };

      services.frr-bgp = {
        enable = true;
        localAS = 65001;
        remoteAS = 65000;
        uplinkPeer = "10.1.100.1";
      };

      services.ovn-bgp-agent = {
        enable = true;
        settings =
          {
            DEFAULT = {
              debug = false;
              bgp_AS = 65001;
              driver = "nb_ovn_bgp_driver";
              exposing_method = "underlay";
              ovsdb_connection = "unix:/var/run/openvswitch/db.sock";
              disable_ipv6 = true;
              log_file = "/var/log/ovn-bgp-agent/ovn-bgp-agent.log";
              use_stderr = false;
            };
            ovn = {
              ovn_nb_connection = "tcp:10.1.100.5:6641";
              ovn_sb_connection = "tcp:10.1.100.5:6642";
            };
            agent.root_helper = "";
          };
      };
      systemd.services.ovn-northd.unitConfig.ConditionHost = "dalet";

      services.prometheus.exporters.ganeti = {
        enable = true;
        settings.ganeti.api = "https://127.0.0.1:5080";
        settings.ganeti.user = prometheusExporterUser.user;
        settings.ganeti.password = prometheusExporterUser.password;
      };

      boot = {
        kernelParams = [
          "console=tty0"
          "console=ttyS1,19200" # serial over LAN
        ];
        # TCP optimizations from https://linbit.com/blog/independent-performance-testing-of-drbd-by-e4/.
        kernel.sysctl = {
          "net.ipv4.tcp_slow_start_after_idle" = 0;
          "net.core.rmem_max" = 56623104;
          "net.core.wmem_max" = 56623104;
          "net.core.rmem_default" = 56623104;
          "net.core.wmem_default" = 56623104;
          "net.core.optmem_max" = 56623104;
          "net.ipv4.tcp_rmem" = "4096 87380 56623104";
          "net.ipv4.tcp_wmem" = "4096 65536 56623104";
          # Enable forwarding (needed for ovn-bgp-agent)
          "net.ipv4.ip_forward" = 1;
        };
        extraModulePackages = with config.boot.kernelPackages; [
          #drbd # DRBD 9.x
        ];
      };

      systemd.services."serial-getty@ttyS1" = {
        enable = true;
        wantedBy = [ "getty.target" ];
        serviceConfig.Restart = "always";
      };

      documentation = {
        enable = true;
        man = {
          generateCaches = false;
          enable = true;
        };
      };

      services.fwupd.enable = true;
      services.fstrim.enable = true;

      disko.devices = {
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

      provisioning.disks.enable = true;

      environment.systemPackages = with pkgs;
        [
          python3
          git
          ethtool
          iperf3
          inetutils
          netcat
          linux-manual
          man-pages
          man-pages-posix
          nettools # arp
          arping
          dig
          vim
          swtpm # for TPM support
          vdo # for vdoformat
          qemu
          iftop
          sysstat # iostat, sar
          pciutils # lspci
          smartmontools # smartctl
          nvme-cli
          fio
          stress-ng
          tcpdump
          lsof
        ];

      system.activationScripts.vdoSetup = {
        deps = [ "specialfs" ];
        text = ''
          ln -sf ${pkgs.vdo}/bin/vdoformat /usr/bin/vdoformat
        '';
      };

      # Recommended by Ganeti setup: prevent LVM from automatically scanning
      # DRBD devices for PV/VG/LV signatures. Note that this overwrites
      # `lvm.conf`, which is empty by default, unless you use snapshots, thin
      # volumes etc.
      # (see https://docs.ganeti.org/docs/ganeti/3.0/html/install.html#id24).
      environment.etc."/lvm/lvm.conf".text = mkForce ''
        devices {
          filter = ["r|/dev/drbd[0-9]+|"]
        }
      '';
    };
}
