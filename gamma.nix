{ config }:

let common = import ./common.nix { inherit config; }; in
common // {
  networking.hostName = "gamma";
}
