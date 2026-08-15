self: super:
let
  rev = "97da76040a6b31aaf9e12f1a167e77ca2b3cb43e";

  # Custom DRBD 9.3.3 kernel module. Defined once so it can be applied to every
  # kernel package set (via linuxPackagesFor), not just the default kernel's.
  drbdModule = kprev: kprev.drbd.overrideAttrs
    (oldAttrs: rec {
      version = "9.3.3";
      src = super.fetchgit {
        inherit rev;
        url = "https://github.com/LINBIT/drbd.git";
        hash = "sha256-COdio4Zh4SrPq5c0umg0shPlbfEZmO66rvrxaf3Hf5g=";
      };
      patches = (oldAttrs.patches or [ ]) ++ [
        # In drbd8 compat mode, forget the address-derived node id when
        # the last connection is removed, so that pairing with a new
        # peer (gnt-instance replace-disks) can re-arbitrate node ids.
        ./drbd-9.3.3-compat84-forget-node-id.patch
      ];
      preConfigure = ''
        ${oldAttrs.preConfigure or "" }
        echo -e 'GIT-hash: ${rev}' > ./drbd/.drbd_git_revision
      '';
      makeFlags = oldAttrs.makeFlags ++ [ "CONFIG_DRBD_COMPAT_84=y" ];
      # nixpkgs marks drbd broken on kernel 6.18.x, but LINBIT supports that
      # kernel (the compat system targets the newest upstream kernel), so clear
      # the flag.
      meta = (oldAttrs.meta or { }) // { broken = false; };
    });
in
{
  linuxPackages = super.linuxPackages.extend (kfinal: kprev: {
    drbd = drbdModule kprev;
  });

  # The custom DRBD module is applied to arbitrary kernel package sets via
  # linuxPackagesFor as well, so switching kernels keeps the same module.
  linuxPackagesFor = kernel: (super.linuxPackagesFor kernel).extend (kfinal: kprev: {
    drbd = drbdModule kprev;
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
