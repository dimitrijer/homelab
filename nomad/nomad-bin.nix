# HashiCorp's prebuilt Nomad release.
{ lib, stdenvNoCC, fetchurl, unzip, autoPatchelfHook }:

stdenvNoCC.mkDerivation rec {
  pname = "nomad";
  version = "1.11.3";

  src = fetchurl {
    url = "https://releases.hashicorp.com/nomad/${version}/nomad_${version}_linux_amd64.zip";
    hash = "sha256-GdrFZCorpTBeb/jv7ganCNdg6+TRzXk2vD3FJvR33BI=";
  };

  # The binary is dynamically linked against glibc.
  nativeBuildInputs = [ unzip autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 nomad $out/bin/nomad
    runHook postInstall
  '';

  meta = with lib; {
    description = "Workload orchestrator (HashiCorp release binary)";
    homepage = "https://www.nomadproject.io/";
    license = licenses.bsl11;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "nomad";
  };
}
