# Feature-trimmed QEMU for Ganeti KVM instances.
self: super: {
  qemu-minimal = super.qemu.override {
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
    openGLSupport = false;
    virglSupport = false;
  };
}
