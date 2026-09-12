# DRBD 9.x kernel module and matching drbd-utils.
self: super:
let
  kernelRev = "97da76040a6b31aaf9e12f1a167e77ca2b3cb43e";
  utilsRev = "13c39bae4d340ed177e4abe5793b80478f6ad8cb";
in
{
  # Kernel module, built for whatever kernel package set the image uses:
  #   boot.extraModulePackages = [ (pkgs.drbd-kernel-module config.boot.kernelPackages) ];
  drbd-kernel-module = kernelPackages: kernelPackages.drbd.overrideAttrs (oldAttrs: {
    version = "9.3.3";
    src = super.fetchgit {
      url = "https://github.com/LINBIT/drbd.git";
      rev = kernelRev;
      hash = "sha256-COdio4Zh4SrPq5c0umg0shPlbfEZmO66rvrxaf3Hf5g=";
    };
    patches = (oldAttrs.patches or [ ]) ++ [
      # In drbd8 compat mode, forget the address-derived node id when
      # the last connection is removed, so that pairing with a new
      # peer (gnt-instance replace-disks) can re-arbitrate node ids.
      ./drbd-9.3.3-compat84-forget-node-id.patch
    ];
    preConfigure = ''
      ${oldAttrs.preConfigure or ""}
      echo -e 'GIT-hash: ${kernelRev}' > ./drbd/.drbd_git_revision
    '';
    makeFlags = oldAttrs.makeFlags ++ [ "CONFIG_DRBD_COMPAT_84=y" ];
    # nixpkgs marks drbd broken on kernel 6.18.x, but LINBIT supports that
    # kernel (the compat system targets the newest upstream kernel), so clear
    # the flag.
    meta = (oldAttrs.meta or { }) // { broken = false; };
  });

  # Userland (drbdadm, drbdsetup, drbdmeta).
  drbd-utils-9 = super.drbd.overrideAttrs (oldAttrs: {
    version = "9.34.0";
    src = super.fetchgit {
      url = "https://github.com/LINBIT/drbd-utils.git";
      rev = utilsRev;
      hash = "sha256-g+HmOEVRO3CrmTqn7/bBUen2B92tAtTY0HY6AezkcYc=";
      fetchSubmodules = true;
    };
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ (with super; [ autoconf automake git ]);
    preConfigure = ''
      ${oldAttrs.preConfigure or ""}
      ./autogen.sh
      echo -e '#define GITHASH "${utilsRev}"\n#define GITDIFF "0"' > ./user/shared/drbd_buildtag.h
    '';
  });
}
