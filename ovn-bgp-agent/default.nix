{ lib
, python3
, fetchFromGitHub
, openstackPythonPackages
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

  # Disable tests for initial packaging
  doCheck = false;

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
