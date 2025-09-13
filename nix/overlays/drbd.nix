self: super: {
  linuxPackages = super.linuxPackages.extend
    (kfinal: kprev: {
      drbd = kprev.drbd.overrideAttrs
        (oldAttrs: rec {
          version = "9.2.15-rc.1";
          src = super.fetchurl {
            url = "https://pkg.linbit.com/downloads/drbd/9/drbd-${version}.tar.gz";
            hash = "sha256-67bjS6CK4zrW1suIxMO4na3vFT8Xpzbw095b0/8WhUY=";
          };
          makeFlags = oldAttrs.makeFlags ++ [ "CONFIG_DBRD_COMPAT_84=true" ];
        });
    });
  drbd = super.drbd.overrideAttrs
    (oldAttrs: rec {
      version = "9.32.0";
      src = super.fetchurl {
        url = "https://pkg.linbit.com/downloads/drbd/utils/${oldAttrs.pname}-utils-${version}.tar.gz";
        hash = "sha256-szOM7jSbXEZZ4p1P73W6tK9Put0+wOZar+cUiUNC6M0=";
      };
    });
}
