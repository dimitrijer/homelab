self: super: {
  drbd = super.drbd.overrideAttrs
    (oldAttrs: rec {
      version = "9.32.0";
      src = super.fetchurl {
        url = "https://pkg.linbit.com/downloads/drbd/utils/${oldAttrs.pname}-utils-${version}.tar.gz";
        hash = "sha256-szOM7jSbXEZZ4p1P73W6tK9Put0+wOZar+cUiUNC6M0=";
      };
    });
}
