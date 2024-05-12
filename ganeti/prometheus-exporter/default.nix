{ lib, stdenv, fetchFromGitHub, python3 }:

stdenv.mkDerivation {
  pname = "prometheus-ganeti-exporter";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "ganeti";
    repo = "prometheus-ganeti-exporter";
    rev = "22ecafc45814f6a89dc86d25f668b9f811c7814b";
    hash = "sha256-JHnXYwYl7VLD/nKlQS9eGATXhLKBKNEAwjbJ404mipM=";
  };

  propagatedBuildInputs = [
    (python3.withPackages (ps: with ps; [
      prometheus-client
      requests
      urllib3
    ]))
  ];

  installPhase = "install -Dm755 ./prometheus-ganeti-exporter $out/bin/prometheus-ganeti-exporter";

  meta = with lib; {
    description = "Prometheus exporter for Ganeti metrics";
    license = licenses.bsd2;
    mainProgram = "prometheus-ganeti-exporter";
  };
}
