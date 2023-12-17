{ config }:

{
  console.keyMap = "us";
  users.users.dimitrije = {
    isNormalUser = true;
    home = "/home/dimitrije";
    description = "Dimitrije Radojevic";
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJklWVMXaRPHb2+px018aQdEldAtzt9+MZHqImMmDFZa dimitrije@prospect" ];
  };
  system.stateVersion = config.system.nixos.release;
}
