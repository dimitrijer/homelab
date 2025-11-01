{ lib
, python3
, fetchFromGitHub
, openstackPythonPackages
, ovs
, sudo
, makeWrapper
, frr
, procps
}:

python3.pkgs.buildPythonApplication rec {
  pname = "ovn-bgp-agent";
  version = "5.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "ovn-bgp-agent";
    rev = version;
    hash = "sha256-5LL7cnwgqknlSEpG8AYSXxsKjVFze38/uKILzlOK9+o=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  patches = [
    ./ovn-bgp-agent-use-fork-method-when-root.patch
    ./ovn-bgp-agent-fix-get-lrp-ports-return.patch
    ./ovn-bgp-agent-use-vtysh-from-path.patch
    ./ovn-bgp-agent-add-debug-logging.patch
    ./ovn-bgp-agent-add-disable-ipv6-option.patch
    ./ovn-bgp-agent-fix-routing-tables-dict-bug.patch
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  build-system = with python3.pkgs; [
    setuptools
    pbr
  ];

  dependencies = with python3.pkgs; [
    jinja2
    netaddr
    oslo-concurrency
    oslo-config
    oslo-log
    pyroute2
    stevedore
    tenacity
  ] ++ (with openstackPythonPackages; [
    ovs
    oslo-privsep
    oslo-rootwrap
    oslo-service
    neutron-lib
    ovsdbapp
  ]);

  nativeCheckInputs = with python3.pkgs; [
    stestr
    oslotest
    testtools
    eventlet
    hacking
    pyroute2
  ];

  checkPhase = ''
    runHook preCheck
    stestr run
    runHook postCheck
  '';

  postInstall = ''
    wrapProgram $out/bin/ovn-bgp-agent \
      --prefix PATH : ${lib.makeBinPath [ sudo ovs frr procps ]}
  '';

  pythonImportsCheck = [
    "ovn_bgp_agent"
  ];

  meta = with lib; {
    description = "OVN BGP Agent allows to expose VMs/Containers/Networks through BGP on OVN";
    homepage = "https://github.com/openstack/ovn-bgp-agent";
    changelog = "https://github.com/openstack/ovn-bgp-agent/releases/tag/${version}";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "ovn-bgp-agent";
  };
}
