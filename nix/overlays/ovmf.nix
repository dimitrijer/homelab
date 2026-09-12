# UEFI firmware with Secure Boot / TPM / HTTP boot support but *without* the
# SMM requirement, so it also boots on the i440fx ("pc") machine type.
self: super: {
  OVMF-nosmm = super.OVMF.override {
    secureBoot = true;
    tpmSupport = true;
    tlsSupport = true;
    httpSupport = true;
    msVarsTemplate = true;
    systemManagementModeRequired = false;
  };
}
