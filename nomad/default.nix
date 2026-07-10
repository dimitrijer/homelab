{ lib, buildGoModule, fetchFromGitHub, pkg-config, libvirt, qemu-utils }:

buildGoModule rec {
  pname = "nomad-driver-virt";
  version = "0.0.1-dev";

  src = fetchFromGitHub {
    owner = "dimitrijer";
    repo = "nomad-driver-virt";
    rev = "063ffa23daaafd2e4b7420f40f6a9a8963e7cd07"; # ovn-claude
    hash = "sha256-HchaZpySDFDDAZEh2oPZ9/rfheaDQP6PNMZ8JrlDqXQ=";
  };

  vendorHash = "sha256-zlIHyqE4wSWoh730JZNMCQgh3fy2BwWa0sz0ZKMEq6E=";

  subPackages = [ "." ];

  env.CGO_ENABLED = "1";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libvirt ];
  nativeCheckInputs = [ qemu-utils ];

  ldflags = [
    "-X github.com/hashicorp/nomad-driver-virt/version.GitCommit=063ffa2"
    "-X github.com/hashicorp/nomad-driver-virt/version.GitDescribe=v${version}"
  ];

  meta = with lib; {
    description = "Nomad task driver for managing QEMU/KVM virtual machines via libvirt";
    homepage = "https://github.com/dimitrijer/nomad-driver-virt/tree/ovn-claude";
    license = licenses.mpl20;
    platforms = platforms.linux;
  };
}
