self: super: {
  linuxPackages = super.linuxPackages.extend
    (kfinal: kprev: {
      drbd = let rev = "d3838e6f08d1e56882b8d7265fc9032c2ef8c9cb"; in kprev.drbd.overrideAttrs
        (oldAttrs: rec {
          version = "9.3.0";
          src = super.fetchgit {
            inherit rev;
            url = "https://github.com/LINBIT/drbd.git";
            hash = "sha256-ijPqeVTBE3bvwKtrHN6NeNg7qx0xBLDqW9dulO/davo=";
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
