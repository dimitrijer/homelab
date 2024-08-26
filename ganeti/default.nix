{ lib
, stdenv
, fetchgit
, autoreconfHook
, makeWrapper
, breakpointHook
, ghc
, python3
, coreutils
, util-linux
, procps
, iproute
, socat
, iputils
, fping
, ndisc6 # for IPv6
, curl # needed for headers only
, fakeroot
, systemd
, multipath-tools
, openvswitch
, gnutar
, lvm2
, openssh
, drbd
, man
, pandoc
, graphviz
, qemu-utils # for ovfimport
, qemu
, glibcLocales
, OVMF # for UEFI boot / SecureBoot
, buildDocs ? true
}:

let
  pythonWithPackages =
    python3.withPackages
      (ps: with ps; [
        pyopenssl
        simplejson
        pyparsing
        pyinotify
        pycurl
        bitarray
        psutil
        paramiko
        pyyaml # for unit tests
        mock # for unit tests
      ] ++
      lib.optionals
        buildDocs [ sphinx ]);
  ghcWithPackages = ghc.ghcWithPackages (ps: with ps;
    [
      Cabal_3_6_2_0 # Cabal library version has to match cabal-install version
      cabal-install
      ps.curl
      json
      network
      bytestring
      base64-bytestring
      utf8-string
      mtl
      zlib
      hslogger
      attoparsec
      process
      vector
      text
      hinotify
      cryptonite
      lifted-base
      lens
      regex-pcre
      old-time
      temporary
      case-insensitive
      snap-server # for monitoring
      PSQueue # for monitoring
      # unit test dependencies below
      hlint
      QuickCheck
      test-framework
      test-framework-hunit
      test-framework-quickcheck2
    ] ++ lib.optionals buildDocs [
      hscolour # hsapi documentation
    ]);
in
stdenv.mkDerivation
rec {
  pname = "ganeti";
  version = "unstable-2024-07-26";
  src = fetchgit {
    url = "https://github.com/ganeti/ganeti.git";
    rev = "6c452f3a0525fb7a7aaba941891597f25fdabe88";
    hash = "sha256-aC2uUvqawVN8FC08CbBtuSeMU2QrChnrgmvAtIkVSG8=";
    leaveDotGit = true; # We should really manually create the version vsc file.
  };

  nativeBuildInputs = [
    autoreconfHook
    breakpointHook
    makeWrapper
    fakeroot # for tests requiring fakeroot
    coreutils
    glibcLocales
  ];

  nativeCheckInputs = [
    fakeroot
    openssh
    procps
    coreutils
  ];

  propagatedBuildInputs = [
    iproute
    socat
    qemu-utils
    coreutils
    util-linux
    procps
    systemd
    gnutar
    lvm2
    iproute
    iputils
    fping
    ndisc6
    openssh
    openvswitch
    multipath-tools
    systemd
    drbd
    OVMF
  ];

  buildInputs = [
    curl
    pythonWithPackages
    ghcWithPackages
    pandoc # for man pages
    man # for man pages
  ]
  ++ lib.optionals buildDocs [ graphviz ]
  ;

  patches = [
    # patches from https://github.com/jfut/ganeti-rpm
    ./ganeti-2.16.1-fix-new-cluster-node-certificates.patch
    ./ganeti-3.0.0-qemu-migrate-set-parameters-version-check.patch
    ./ganeti-3.0.2-cryptonite-version.patch
    ./ganeti-3.0.2-kvm-qmp-timeout.patch

    # nix-specific patches
    ./ganeti-3.0.2-make-daemons-scripts-executable.patch
    ./ganeti-3.0.2-makefile-am.patch
    ./ganeti-3.0.2-do-not-link-when-running-ssh-cmds.patch
    ./ganeti-3.0.2-disable-incompatible-pytests.patch
  ];

  preConfigure = ''
    patchShebangs ./autotools ./daemons ./tools
  '';

  configureFlags = [
    "--libdir=${placeholder "out"}/lib"
    "--localstatedir=/var"
    "--sysconfdir=${placeholder "out"}/etc"
    "--enable-symlinks"
    "--with-sshd-restart-command=systemctl restart sshd.service"
    "--with-user-prefix=gnt-"
    "--with-group-prefix=gnt-"
    "--with-kvm-path=${qemu.out}/bin/qemu-kvm"
    "--enable-monitoring"
    "--enable-metadata"
    "--enable-haskell-tests"
  ];

  buildPhase = ''
    runHook preBuild
    make really-all
    runHook postBuild
  '';

  doCheck = true;

  preCheck = ''
    substituteInPlace ./test/py/ganeti.utils.process_unittest.py  \
      --replace "[\"env\"]" "[\"${coreutils.out}/bin/env\"]"

    substituteInPlace ./test/py/ganeti.hooks_unittest.py  \
      --replace "/bin/true" "${coreutils.out}/bin/true" \
      --replace "/usr/bin/env" "${coreutils.out}/bin/env" \
  '';

  checkPhase = ''
    runHook preCheck
    make hs-tests py-tests
    runHook postCheck
  '';

  postFixup =
    let
      daemons = [
        "$out/bin/ganeti-cleaner"
        "$out/bin/ganeti-listrunner"
        "$out/bin/ganeti-mond"
        "$out/bin/ganeti-confd"
        "$out/bin/ganeti-luxid"
        "$out/bin/ganeti-noded"
        "$out/bin/ganeti-kvmd"
        "$out/bin/ganeti-metad"
        "$out/bin/ganeti-rapi"
        "$out/bin/ganeti-watcher"
        "$out/bin/ganeti-wconfd"
      ];
      htools = [
        "$out/bin/hcheck"
        "$out/bin/hscan"
        "$out/bin/harep"
        "$out/bin/hinfo"
        "$out/bin/hspace"
        "$out/bin/hbal"
        "$out/bin/hroller"
        "$out/bin/hsqueeze"
      ];
      pythonBinaries = [
        "$out/bin/gnt-cluster"
        "$out/bin/gnt-group"
        "$out/bin/gnt-network"
        "$out/bin/gnt-storage"
        "$out/bin/gnt-debug"
        "$out/bin/gnt-instance"
        "$out/bin/gnt-node"
        "$out/bin/gnt-backup"
        "$out/bin/gnt-filter"
        "$out/bin/gnt-job"
        "$out/bin/gnt-os"
      ];
      tools = [
        "$out/lib/ganeti/tools/master-ip-setup"
        "$out/lib/ganeti/tools/burnin"
        "$out/lib/ganeti/tools/cfgupgrade"
        "$out/lib/ganeti/tools/cluster-merge"
        "$out/lib/ganeti/tools/fmtjson"
        "$out/lib/ganeti/tools/lvmstrap"
        "$out/lib/ganeti/tools/move-instance"
        "$out/lib/ganeti/tools/ovfconverter"
        "$out/lib/ganeti/tools/query-config"
        "$out/lib/ganeti/tools/users-setup"
        "$out/lib/ganeti/tools/xen-console-wrapper"
        "$out/lib/ganeti/tools/cfgshell"
        "$out/lib/ganeti/tools/cfgupgrade12"
        "$out/lib/ganeti/tools/confd-client"
        "$out/lib/ganeti/tools/kvm-console-wrapper"
        "$out/lib/ganeti/tools/master-ip-setup"
        "$out/lib/ganeti/tools/node-cleanup"
        "$out/lib/ganeti/tools/post-upgrade"
        "$out/lib/ganeti/tools/sanitize-config"
        "$out/lib/ganeti/tools/vcluster-setup"
      ];
      binPath = lib.makeBinPath propagatedBuildInputs;
    in
    lib.intersperse "\n"
      (map
        (prog: "wrapProgram ${prog} --prefix PATH : \"${binPath}\"")
        (daemons ++ htools ++ pythonBinaries ++ tools));

  installPhase = ''
    make install
    install -d -m 755 $out/etc/bash_completion.d
    install -d -m 755 $out/etc/cron.d
    install -d -m 755 $out/etc/default
    install -d -m 755 $out/etc/logrotate.d
    install -d -m 755 $out/lib/systemd/system

    install -m 644 doc/examples/bash_completion $out/etc/bash_completion.d/ganeti
    install -m 644 doc/examples/ganeti.cron $out/etc/cron.d/ganeti
    install -m 644 doc/examples/ganeti.default $out/etc/default/ganeti
    install -m 644 doc/examples/ganeti.logrotate $out/etc/logrotate.d/ganeti

    install -m 644 doc/examples/systemd/ganeti-common.service $out/lib/systemd/system/ganeti-common.service
    install -m 644 doc/examples/systemd/ganeti-confd.service  $out/lib/systemd/system/ganeti-confd.service
    install -m 644 doc/examples/systemd/ganeti-kvmd.service   $out/lib/systemd/system/ganeti-kvmd.service
    install -m 644 doc/examples/systemd/ganeti-luxid.service  $out/lib/systemd/system/ganeti-luxid.service
    install -m 644 doc/examples/systemd/ganeti-metad.service  $out/lib/systemd/system/ganeti-metad.service
    install -m 644 doc/examples/systemd/ganeti-mond.service   $out/lib/systemd/system/ganeti-mond.service
    install -m 644 doc/examples/systemd/ganeti-noded.service  $out/lib/systemd/system/ganeti-noded.service
    install -m 644 doc/examples/systemd/ganeti-rapi.service   $out/lib/systemd/system/ganeti-rapi.service
    install -m 644 doc/examples/systemd/ganeti-wconfd.service $out/lib/systemd/system/ganeti-wconfd.service

    install -m 644 doc/examples/systemd/ganeti-master.target  $out/lib/systemd/system/ganeti-master.target
    install -m 644 doc/examples/systemd/ganeti-node.target    $out/lib/systemd/system/ganeti-node.target
    install -m 644 doc/examples/systemd/ganeti.service        $out/lib/systemd/system/ganeti.service
    install -m 644 doc/examples/systemd/ganeti.target         $out/lib/systemd/system/ganeti.target
  '';
}
