{ modulesPath, ... }:

{
  imports = [
    ./common.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.kernelParams = [
    "console=tty0"
    "console=ttyS0,115200" # gnt serial console
  ];

  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
    serviceConfig.Restart = "always";
  };

  # Mask systemd-ssh-generator - we don't use AF_VSOCK for SSH access
  systemd.generators.systemd-ssh-generator = "/dev/null";
}
