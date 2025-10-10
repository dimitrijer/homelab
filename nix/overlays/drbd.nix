self: super: {
  linuxPackages = super.linuxPackages.extend
    (kfinal: kprev: {
      drbd = kprev.drbd.overrideAttrs
        (oldAttrs: rec {
          version = "9.2.15";
          src = super.fetchurl {
            url = "https://pkg.linbit.com/downloads/drbd/9/drbd-${version}.tar.gz";
            hash = "sha256-bKaL7wtjlSbUkLRlMSrGYjab0jdS8lu5bgScTbfpllE=";
          };
          makeFlags = oldAttrs.makeFlags ++ [ "CONFIG_DRBD_COMPAT_84=y" ];
        });
    });
  drbd = super.drbd.overrideAttrs
    (oldAttrs: rec {
      version = "9.32.0";
      preConfigure = ''
        ${oldAttrs.preConfigure or ""}
        ./autogen.sh

        echo -e '#define GITHASH "0"\n#define GITDIFF "0"' > ./user/shared/drbd_buildtag.h
      '';

      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ (with super;
        [ autoconf automake git ]);

      src = super.fetchgit {
        url = "https://github.com/LINBIT/drbd-utils.git";
        rev = "fa022500e8401a1004095fd3347325b4a837ccd5";
        hash = "sha256-+VMu4Oax29IOyxZXjBuxlUrZcxJjBACp0pC1/TGn1fg=";
        fetchSubmodules = true;
      };
    });
}
