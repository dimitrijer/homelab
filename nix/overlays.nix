self: super: {
  qemu = super.qemu.override {
    alsaSupport = false;
    pulseSupport = false;
    sdlSupport = false;
    gtkSupport = false;
    vncSupport = true;
    smartcardSupport = false;
    spiceSupport = false;
    ncursesSupport = false;
    usbredirSupport = false;
    hostCpuTargets = [ "x86_64-softmmu" ];
    # when using newer qemu, disable these
    #pipewireSupport = false
    #jackSupport = false
  };

  ghc = super.haskell.packages.ghc884;
}
