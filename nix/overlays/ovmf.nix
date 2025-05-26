self: super: {
  OVMF = super.OVMF.override {
    secureBoot = true;
    tpmSupport = true;
    tlsSupport = true;
    httpSupport = true;
    msVarsTemplate = true;
    systemManagementModeRequired = false;
  };
}
