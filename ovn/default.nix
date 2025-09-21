# This was mostly taken from upstream ovn package, except that this one
# provides OVS as well.

{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
, gnused
, libbpf
, libcap_ng
, libtool
, nix-update-script
, numactl
, openssl
, pkg-config
, procps
, python3
, unbound
, xdp-tools
, tcpdump
, installShellFiles
, makeWrapper
, perl
, util-linux
, which
, gawk
}:

stdenv.mkDerivation rec {
  pname = "ovn";
  version = "25.09.0";

  src = fetchFromGitHub {
    owner = "ovn-org";
    repo = "ovn";
    tag = "v${version}";
    hash = "sha256-DNaf3vWb6tlzViMEI02+3st/0AiMVAomSaiGplcjkIc=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    libtool
    installShellFiles
    python3
    makeWrapper
  ];

  buildInputs = [
    perl
    procps
    python3
    util-linux
    which
    libcap_ng
    numactl
    openssl
    unbound
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isStatic) [
    libbpf
    xdp-tools
  ];

  # need to build the ovs submodule first
  preConfigure = ''
    pushd ovs
    ./boot.sh
    ./configure \
      --prefix=$out \
      --with-dbdir=/var/lib/openvswitch \
      --localstatedir=/var \
      --sharedstatedir=/var \
      --sbindir=$out/bin
    make -j $NIX_BUILD_CORES
    popd
  '';

  configureFlags = [
    "--localstatedir=/var"
    "--sharedstatedir=/var"
    "--with-dbdir=/var/lib/ovn"
    "--sbindir=$(out)/bin"
    "--enable-ssl"
  ]
  ++ lib.optional stdenv.hostPlatform.isStatic "--with-openssl=${lib.getLib openssl.dev}";

  enableParallelBuilding = true;

  # disable tests due to networking issues and because individual tests can't be skipped easily
  doCheck = false;

  nativeCheckInputs = [
    gnused
    procps
  ];

  installPhase = ''
    runHook preInstall

    pushd ovs
    make LOGDIR=$TMPDIR/dummy RUNDIR=$TMPDIR/dummy PKIDIR=$TMPDIR/dummy install
    popd

    make install

    runHook postInstall
  '';

  # TODO: gawk missing from share/ovn/scripts/ovn-lib AND share/openvswitch/scripts/ovs-lib
  postInstall = ''
    mkdir -vp $out/share/openvswitch/scripts
    mkdir -vp $out/etc/ovn

    wrapProgram $out/bin/ovs-l3ping \
      --prefix PYTHONPATH : $out/share/openvswitch/python

    wrapProgram $out/bin/ovs-tcpdump \
      --prefix PATH : ${lib.makeBinPath [ tcpdump ]} \
      --prefix PYTHONPATH : $out/share/openvswitch/python

    installShellCompletion --bash ovs/utilities/ovs-appctl-bashcomp.bash
    installShellCompletion --bash ovs/utilities/ovs-vsctl-bashcomp.bash

    cp ovs/utilities/ovs-ctl $out/share/openvswitch/scripts
    cp ovs/utilities/ovs-lib $out/share/openvswitch/scripts
    cp ovs/utilities/ovs-kmod-ctl $out/share/openvswitch/scripts
    cp ovs/vswitchd/vswitch.ovsschema $out/share/openvswitch
    sed -i "s#/usr/local/etc#/var/lib#g" $out/share/openvswitch/scripts/ovs-lib
    sed -i "s#/usr/local/bin#$out/bin#g" $out/share/openvswitch/scripts/ovs-lib
    sed -i "s#/usr/local/sbin#$out/bin#g" $out/share/openvswitch/scripts/ovs-lib
    sed -i "s#/usr/local/share#$out/share#g" $out/share/openvswitch/scripts/ovs-lib
    sed -i '/chown -R $INSTALL_USER:$INSTALL_GROUP $ovn_etcdir/d' $out/share/ovn/scripts/ovn-ctl
  '';

  # https://docs.ovn.org/en/latest/topics/testing.html
  preCheck = ''
    export TESTSUITEFLAGS="-j$NIX_BUILD_CORES"
    # allow rechecks to retry flaky tests
    export RECHECK=yes

    # hack to stop tests from trying to read /etc/resolv.conf
    export OVS_RESOLV_CONF="$PWD/resolv.conf"
    touch $OVS_RESOLV_CONF
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Open Virtual Network";
    longDescription = ''
      OVN (Open Virtual Network) is a series of daemons that translates virtual network configuration into OpenFlow, and installs them into Open vSwitch.
    '';
    homepage = "https://github.com/ovn-org/ovn";
    changelog = "https://github.com/ovn-org/ovn/blob/${src.rev}/NEWS";
    license = licenses.asl20;
    maintainers = with maintainers; [ adamcstephens ];
    platforms = platforms.linux;
  };
}
