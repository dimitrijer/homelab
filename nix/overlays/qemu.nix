self: super:
let
  # Just use qemu features / targets that are actually needed.
  qemuOverrides = {
    hostCpuTargets = [ "i386-softmmu" "x86_64-softmmu" ];
    vncSupport = true;
    alsaSupport = false;
    pulseSupport = false;
    pipewireSupport = false;
    sdlSupport = false;
    jackSupport = false;
    gtkSupport = false;
    smartcardSupport = false;
    spiceSupport = false;
    ncursesSupport = false;
    usbredirSupport = false;
    xenSupport = false;
    cephSupport = false;
    glusterfsSupport = false;
    openGLSupport = false;
    virglSupport = false;
  };
in
{
  qemu = super.qemu.override qemuOverrides;
  qemu-utils = (super.qemu.override (qemuOverrides // {
    toolsOnly = true;
  })).overrideAttrs (old: {
    # QEMU 11.0.0 has a compilation error in tests/qtest/migration/tls-tests.c
    # where TLS X509 test types/functions were removed but test code
    # wasn't updated. Replace the broken file with a stub since test
    # binaries aren't needed for qemu-utils (tools only build).
    postPatch = (old.postPatch or "") + ''
      cat > tests/qtest/migration/tls-tests.c << 'EOF'
    #include "qemu/osdep.h"
    #include "libqtest.h"

    void migration_test_add_tls(QTestState *who) { }
    EOF
    '';
  });
}
