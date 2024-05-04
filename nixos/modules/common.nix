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
      ];
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
    ];

  services.prometheus.exporters.node = {
    enable = true;
    openFirewall = true;
    enabledCollectors = [ "systemd" "processes" "drbd" ];
  };
}
