{ config }:

{
  console.keyMap = "us";

  users.users.dimitrije =
    {
      isNormalUser = true;
      home = "/home/dimitrije";
      description = "Dimitrije Radojevic";
      extraGroups = [ "wheel" "networkmanager" ];
      openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJklWVMXaRPHb2+px018aQdEldAtzt9+MZHqImMmDFZa dimitrije@prospect" ];
    };
  users.users.root.initialHashedPassword = "$y$j9T$gChWZEYyiVSALFhhHwI39.$UrwTZVYmKMvUp9tQbcTpaNeYKI7w3uRyZ3KcgqnxcK1";

  system.stateVersion = config.system.nixos.release;

  services.openssh = {
    enable = true;
  };
}
