{ config, pkgs }:

let common = import ./common.nix { inherit pkgs config; }; in
common // {
  networking.hostName = "dalet";
}
