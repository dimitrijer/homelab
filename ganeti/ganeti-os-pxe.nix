{ lib, stdenv, fetchFromGitHub, makeWrapper, coreutils, util-linux, multipath-tools, ipxe }:

stdenv.mkDerivation
{
  pname = "ganeti-os-pxe";
  version = "0.0.1";

  src = fetchFromGitHub {
    owner = "hpc2n";
    repo = "ganeti-os-pxe";
    rev = "ec0f81a4792a6fe67d8c9abffb80c5821e7858fd";
    hash = "sha256-OiIWfMHPCfSZA2H4zegBGXdtaPbedkDWxSCl4HjoOdo=";
  };

  nativeBuildInputs = [ makeWrapper ];

  patches = [ ./ganeti-os-pxe-0.0.1-use-blkid-from-path.patch ];

  installPhase = ''
    mkdir -p $out/pxe
    cp \
      common.sh \
      create \
      export \
      ganeti_api_version \
      import \
      LICENSE.txt \
      README.md \
      rename \
      $out/pxe
  
    # Trick ganeti-os-pxe into baking ipxe instead of bundled PXE binary.
    cp ${ipxe.out}/ipxe.usb $out/pxe/eb-git-virtio-net.zhd
  '';

  postFixup =
    let
      binPath = lib.makeBinPath
        [
          coreutils
          util-linux
          multipath-tools
        ];
    in
    ''
      wrapProgram $out/pxe/create --prefix PATH : "${binPath}"
      wrapProgram $out/pxe/export --prefix PATH : "${binPath}"
      wrapProgram $out/pxe/import --prefix PATH : "${binPath}"
      wrapProgram $out/pxe/rename --prefix PATH : "${binPath}"
    '';

  meta = with lib; {
    license = [ licenses.gpl2Only ];
  };
}
