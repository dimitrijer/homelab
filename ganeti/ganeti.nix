{ lib
, stdenv
, fetchurl
, autoreconfHook
, man
, fakeroot
, iproute
, curl
, socat
, ghc
, python3
, pandoc
, graphviz
, qemu-utils # for ovfimport
, buildDocs ? false
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
      snap-server # mon
      PSQueue # mon
      # Unit test dependencies below
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
{
  pname = "ganeti";
  version = "3.0.2";
  src = fetchurl {
    url = "https://github.com/ganeti/ganeti/releases/download/v3.0.2/ganeti-3.0.2.tar.gz";
    hash = "sha256-l/Myy5qkSiWGLf/Bozcb+M8mZlvN44cl/y5xOWG1DoE=";
  };

  nativeBuildInputs = [
    autoreconfHook
  ];

  buildInputs = [
    fakeroot # for unit tests that require root
    man
    curl
    iproute
    socat
    pythonWithPackages
    ghcWithPackages
    qemu-utils
  ]
  ++ lib.optionals buildDocs [ pandoc graphviz ]
  ;

  patches = [
    ./001-make-daemons-scripts-executable.patch
    ./002-use-shell-from-nix.patch
  ];

  preConfigure = ''
    patchShebangs ./autotools ./daemons
  '';

  configurePhase = ''
    runHook preConfigure

    ./configure \
      --prefix=$out \
      --libdir=$out/lib \
      --localstatedir=$out/var \
      --sysconfdir=$out/etc \
      --enable-symlinks \
      --with-sshd-restart-command="systemctl restart sshd.service" \
      --with-user-prefix=gnt- \
      --with-group-prefix=gnt- \
      --enable-monitoring \
      --enable-metadata \
      --enable-confd \
      --enable-haskell-tests

    runHook postConfigure
  '';

  doCheck = true;

  checkPhase = ''
    make hs-tests
  '';
}
