self: super: {
  linuxPackages = super.linuxPackages.extend
    (kfinal: kprev: {
      drbd = let rev = "97da76040a6b31aaf9e12f1a167e77ca2b3cb43e"; in kprev.drbd.overrideAttrs
        (oldAttrs: rec {
          version = "9.3.3";
          src = super.fetchgit {
            inherit rev;
            url = "https://github.com/LINBIT/drbd.git";
            hash = "sha256-COdio4Zh4SrPq5c0umg0shPlbfEZmO66rvrxaf3Hf5g=";
          };
          preConfigure = ''
            ${oldAttrs.preConfigure or "" } 
            echo -e 'GIT-hash: ${rev}' > ./drbd/.drbd_git_revision
          '';
          makeFlags = oldAttrs.makeFlags ++ [ "CONFIG_DRBD_COMPAT_84=y" ];
        });
    });
  drbd =
    let rev = "13c39bae4d340ed177e4abe5793b80478f6ad8cb";
    in super.drbd.overrideAttrs
      (oldAttrs: rec {
        version = "9.34.0";
        preConfigure = ''
          ${oldAttrs.preConfigure or ""}
          ./autogen.sh

          echo -e '#define GITHASH "${rev}"\n#define GITDIFF "0"' > ./user/shared/drbd_buildtag.h
        '';

        nativeBuildInputs = oldAttrs.nativeBuildInputs ++ (with super;
          [ autoconf automake git ]);

        src = super.fetchgit {
          url = "https://github.com/LINBIT/drbd-utils.git";
          inherit rev;
          hash = "sha256-g+HmOEVRO3CrmTqn7/bBUen2B92tAtTY0HY6AezkcYc=";
          fetchSubmodules = true;
        };
      });
}
