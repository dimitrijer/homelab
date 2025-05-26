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
  qemu-utils = super.qemu.override (qemuOverrides // { toolsOnly = true; });
}
