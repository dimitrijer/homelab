{ pkgs, config, lib, modulesPath, disko, ... }:

with lib;

let
  cfg = config.provisioning.disks;
  disko-fmt = pkgs.writeShellScriptBin "disko-fmt" "${config.system.build.formatScript}";
  disko-mnt = pkgs.writeShellScriptBin "disko-mnt" "${config.system.build.mountScript}";
in
{
  imports = [ ("${disko}/module.nix") ];

  options.provisioning.disks = {
    enable = mkEnableOption "enable disk provisioning";
    ensureDirs = mkOption {
      type = types.listOf (types.submodule {
        options = {
          owner = mkOption { type = types.str; default = "root"; };
          group = mkOption { type = types.str; default = "root"; };
          path = mkOption { type = types.path; };
          mod = mkOption { type = types.int; default = 755; };
        };
      });
      description = "list of directories to ensure exist";
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    disko = {
      # Do not override config.filesystems etc. using disko config.
      enableConfig = mkForce false;
      rootMountPoint = mkForce "/";
    };

    systemd.services."provision-disks" = {
      description = "Provision and/or mount disks";
      before = [ "local-fs.target" "systemd-journald.service" ];
      wants = [ "local-fs-pre.target" ];
      after = [ "local-fs-pre.target" "systemd-udev-settle.service" ];
      requires = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        "StandardOutput" = "file:/dev/kmsg";
        "StandardError" = "file:/dev/kmsg";
      };
      path = with pkgs; [
        coreutils
        gnugrep
        util-linux
        lvm2
        disko-fmt
        disko-mnt
        kmod # for modprobe
      ];
      script =
        let
          blockDevs = lib.attrsets.mapAttrsToList (key: value: value.content.device) config.disko.devices.disk;
          vgs = lib.attrsets.mapAttrsToList (key: value: key) config.disko.devices.lvm_vg;
          vgsList = strings.concatStringsSep " " vgs;
          concatLinesWithIndent = indent: lines: strings.concatStringsSep ("\n" + indent) lines;
          indent = concatLinesWithIndent "  ";
          wipeDisksCmd = indent (map (blockdev: "wipefs -af ${blockdev}") blockDevs);
          rereadPTCmd = indent (map (blockdev: "blockdev --rereadpt ${blockdev}") blockDevs);
          ensureDirsCmd = indent (map (dir: "mkdir -p '${dir.path}'; chown ${dir.owner}:${dir.group} '${dir.path}'; chmod ${toString dir.mod} '${dir.path}'") cfg.ensureDirs);
        in
        ''
          set -eu -o pipefail

          echo "Waiting for disks to settle..."
          sleep 5

          echo "Scanning for VGs..."
          vgscan

          if grep -q "homelab.provision_disks=true" /proc/cmdline
          then
            echo "Preparing to provision disks, as indicated by the kernel cmdline..."

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

            echo "Waiting for disks to settle..."
            sleep 5

            echo "Wiping disks..."
            ${wipeDisksCmd}
            echo "Re-reading partition tables..."
            ${rereadPTCmd}
            echo "Provisioning disks..."
            disko-fmt
          else
            echo "No provision disks found in kernel cmdline, will NOT provision disks..."
          fi

          echo "Mounting local disks..."
          disko-mnt

          echo "Ensuring dirs..."
          ${ensureDirsCmd}
        '';

      unitConfig = {
        DefaultDependencies = "no";
      };
      serviceConfig = {
        Type = "oneshot";
      };
      requiredBy = [ "local-fs.target" "systemd-journald.service" ];
    };

    environment.systemPackages = with pkgs;
      [
        disko-fmt
        disko-mnt
      ];
  };
}
