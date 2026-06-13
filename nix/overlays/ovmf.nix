self: super: {
  OVMF = super.OVMF.override {
    secureBoot = true;
    tpmSupport = true;
    tlsSupport = true;
    httpSupport = true;
    msVarsTemplate = true;
    systemManagementModeRequired = false;
  };

  # OVMF-xen uses OvmfXen.dsc which doesn't support Secure Boot
  # and doesn't build EnrollDefaultKeys.efi, so pass an OVMF with
  # those features disabled.
  OVMF-xen = super.OVMF-xen.override {
    OVMF = self.OVMF.override {
      secureBoot = false;
      msVarsTemplate = false;
    };
  };
}
