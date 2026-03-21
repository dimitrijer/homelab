{ lib, buildGoModule, fetchFromGitHub, pkg-config, libvirt }:

buildGoModule rec {
  pname = "nomad-driver-virt";
  version = "0.0.1-dev";

  src = fetchFromGitHub {
    owner = "hashicorp";
    repo = "nomad-driver-virt";
    rev = "f8c1740";
    hash = "sha256-HmdOHCqhSAA6pieZ6r7DJYa1aWR8k1q+vlxhEgRRHPA=";
  };

  vendorHash = "sha256-BvLtZqzTSFDcbjUMug5VivpLzJlD1FlLu6qWxa3lwEc=";

  subPackages = [ "." ];

  env.CGO_ENABLED = "1";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libvirt ];

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
