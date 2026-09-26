{ lib, rustPlatform, fetchgit }:

rustPlatform.buildRustPackage rec {
  pname = "drbd-reactor";
  version = "1.12.0";

  src = fetchgit {
    url = "https://github.com/LINBIT/drbd-reactor.git";
    rev = "v${version}";
    hash = "sha256-4OrlaLVI3sc+N/pzqaJWiJtQ35vc6RwUAkzGWuruM9Y=";
  };

  cargoHash = "sha256-yUbOegnFatV/SEeKL0otAXi/hW6hCVeVTBkRV6ZaCms=";

  meta = with lib; {
    description = "Monitors DRBD resources via plugins (promoter, Prometheus exporter, ...)";
    homepage = "https://github.com/LINBIT/drbd-reactor";
    license = licenses.asl20;
    platforms = platforms.linux;
    mainProgram = "drbd-reactor";
  };
}
