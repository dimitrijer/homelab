self: super: {
  linuxPackages = super.linuxPackages.extend
    (kfinal: kprev: {
      drbd = kprev.drbd.overrideAttrs
        (oldAttrs: rec {
          version = "9.2.15";
          src = super.fetchgit {
            url = "https://github.com/LINBIT/drbd.git";
            rev = "d3838e6f08d1e56882b8d7265fc9032c2ef8c9cb";
            hash = "sha256-ijPqeVTBE3bvwKtrHN6NeNg7qx0xBLDqW9dulO/davo=";
          };
          makeFlags = oldAttrs.makeFlags ++ [ "CONFIG_DRBD_COMPAT_84=y" ];
        });
    });
  drbd = super.drbd.overrideAttrs
    (oldAttrs: rec {
      version = "9.33.0";
      preConfigure = ''
        ${oldAttrs.preConfigure or ""}
        ./autogen.sh

        echo -e '#define GITHASH "0"\n#define GITDIFF "0"' > ./user/shared/drbd_buildtag.h
      '';

      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ (with super;
        [ autoconf automake git ]);

      src = super.fetchgit {
        url = "https://github.com/LINBIT/drbd-utils.git";
        rev = "abd47fbdf079d96766e4312f52eef038fc2c6723";
        hash = "sha256-WeQd2q/WgjNpXrTnkegEwVVg9r8wsQmAWbmXgrhoXbY=";
        fetchSubmodules = true;
      };
    });
}
