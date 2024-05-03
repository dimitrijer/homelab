{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.provisioning.keys;
in
{
  options.provisioning.keys = {
    enable = mkEnableOption "enable provisioning of root and host keys";
    baseUrl = mkOption {
      type = types.str;
      default = "http://10.1.100.1/keys/";
    };
    before = mkOption {
      type = types.listOf types.str;
      description = "list of systemd services / targets that require this service";
      default = [ "sshd.service" ];
    };
    requiredBy = mkOption {
      type = types.listOf types.str;
      description = "list of systemd services / targets that require this service";
      default = [ "sshd.service" ];
    };
  };

  config = mkIf cfg.enable {
    systemd.services."provision-keys" = {
      description = "Provision root and host keys";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = cfg.before ++ lib.optionals config.services.openssh.enable [ "sshd.service" ];

      path = with pkgs; [ coreutils curl openssh gnutar gzip ];
      script = ''
        set -eu -o pipefail

        root_ssh_dir=/root/.ssh
        mkdir -p $root_ssh_dir
        root_key_path=$root_ssh_dir/id_ed25519
        host_key_path=/etc/ssh/ssh_host_rsa_key
        if [ ! -f $root_key_path ]; then
          # wait for DHCP
          sleep 5
          target_dir=$(mktemp -d provision-keys.XXXXX)
          trap "rm -rf $target_dir" EXIT
          cd $target_dir

          curl -sLO ${cfg.baseUrl}/$HOSTNAME.tar.gz
          umask 077
          tar -xzvf $HOSTNAME.tar.gz
          cp host_privkey $host_key_path
          cp root_privkey $root_key_path
          umask 022
          ssh-keygen -yf $host_key_path >$host_key_path.pub
          root_fingerprint=$(ssh-keygen -lf $root_key_path)
          host_fingerprint=$(ssh-keygen -lf $host_key_path.pub)
          echo "Downloaded private root key to $root_key_path (fingerprint=$root_fingerprint)"
          echo "Downloaded private host key to $host_key_path (fingerprint=$host_fingerprint)"
        else
          echo "Key already exists, nothing to do."
        fi
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        Restart = "on-failure";
        RestartSec = "10";
      };
      wantedBy = [ "multi-user.target" ];
      requiredBy = cfg.requiredBy ++ lib.optionals config.services.openssh.enable [ "sshd.service" ];
    };

    # Do not generate host keys, these are provisioned by provision-keys.service.
    services.openssh = {
      hostKeys = lib.mkForce [ ];
    };
  };
}
