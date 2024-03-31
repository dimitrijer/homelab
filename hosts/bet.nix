{ config, pkgs }:

let common = import ./common.nix { inherit config pkgs; }; in
common // {
  networking.hostName = "bet";
}
