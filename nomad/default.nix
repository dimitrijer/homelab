{ lib, buildGoModule, fetchFromGitHub, pkg-config, libvirt, qemu-utils }:

buildGoModule rec {
  pname = "nomad-driver-virt";
  version = "0.0.1-dev";

  src = /home/dimitrije/git/nomad-driver-virt;

  vendorHash = "sha256-BvLtZqzTSFDcbjUMug5VivpLzJlD1FlLu6qWxa3lwEc=";

  subPackages = [ "." ];

  env.CGO_ENABLED = "1";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libvirt ];
  nativeCheckInputs = [ qemu-utils ];

  ldflags = [
    "-X github.com/hashicorp/nomad-driver-virt/version.GitCommit=f8c1740"
    "-X github.com/hashicorp/nomad-driver-virt/version.GitDescribe=v${version}"
  ];

  meta = with lib; {
    description = "Nomad task driver for managing QEMU/KVM virtual machines via libvirt";
    homepage = "https://github.com/hashicorp/nomad-driver-virt";
    license = licenses.mpl20;
    platforms = platforms.linux;
  };
}
