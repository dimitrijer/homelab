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
      default = "/keys/";
    };
  };

  config = mkIf cfg.enable {
    systemd.services."provision-keys" = {
      description = "Provision root and host keys";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      before = [ ] ++ lib.optionals config.services.openssh.enable [ "sshd.service" ];

      path = with pkgs; [ coreutils curl openssh gnutar gzip gawk iproute2 ];
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

          gw=$(ip route show 0.0.0.0/0 | awk '{ print $3 '})
          curl -sLO "http://$gw${cfg.baseUrl}/$HOSTNAME.tar.gz"
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
      requiredBy = [ ] ++ lib.optionals config.services.openssh.enable [ "sshd.service" ];
    };

    # Do not generate host keys, these are provisioned by provision-keys.service.
    services.openssh = {
      hostKeys = lib.mkForce [ ];
    };
  };
}
