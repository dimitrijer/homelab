{
  mkLayout = { vgName ? "pool_state", homeSize ? "1G", swapSize ? "1G" }:
    {
      disk.hdd = {
        device = "/dev/vda";
        type = "disk";
        name = "hdd";
        content = {
          type = "lvm_pv";
          vg = vgName;
        };
      };

      lvm_vg."${vgName}" = {
        type = "lvm_vg";
        lvs = {
          home = {
            size = homeSize;
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/home";
            };
          };
          swap = {
            size = swapSize;
            content = {
              type = "swap";
            };
          };
          var = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/var";
            };
          };
        };
      };
    };
}
