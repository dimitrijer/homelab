{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  users.users.dimitrije =
    {
      isNormalUser = true;
      home = "/home/dimitrije";
      description = "Dimitrije Radojevic";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJklWVMXaRPHb2+px018aQdEldAtzt9+MZHqImMmDFZa dimitrije@prospect"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOHY5AGvFXTnIT2XOxN41dwYFwumLN9+FJdgg03i8IQg dimitrije@endurance"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7gdT/00QarOYM33vpSOu/KxCUoj8WuLkB+1QFAJ1+Y dimitrije@mackinaw"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHKi8BBpDsh9SDfVhfuvlyF2dPYkxtiwWZzQ64ibkmcE dimitrije@skiff"
      ];
    };
  users.users.root.initialHashedPassword = "$6$OZ8xMsNhdISbKv8P$mj2ZqKDCBoxy59H/XphKKnQu3yxIHgwwI9hP3CJdIZHWzRh0boT9dfWArJjoIxAUsMpdxtybdKSr0X01Kclf81";
  provisioning.disks = {
    ensureDirs = [{
      path = config.users.users.dimitrije.home;
      owner = "dimitrije";
      group = "users";
    }];
  };

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

  # Will be provided via kernel cmdline.
  networking.hostName = lib.mkForce "";
  console.keyMap = "us";
  time.timeZone = "Europe/London";

  networking.firewall = {
    enable = true;
  };

  services.openssh = {
    enable = true;
  };

  networking.enableIPv6 = false;
  system.stateVersion = config.system.nixos.release;

  environment.systemPackages = with pkgs;
    [
      vim
      inetutils
      dig
      rsync
    ];

  services.prometheus.exporters.node = {
    enable = true;
    openFirewall = true;
    enabledCollectors = [ "systemd" "processes" "drbd" ];
  };
}
