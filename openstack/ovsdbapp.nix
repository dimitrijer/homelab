{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, fixtures
, netaddr
, oslo-log
, oslo-serialization
, oslo-utils
, ovs
, stestr
, oslotest
, testtools
, testscenarios
}:

buildPythonPackage rec {
  pname = "ovsdbapp";
  version = "2.13.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "ovsdbapp";
    rev = version;
    hash = "sha256-APt6JARNbntypU2lSn0Th8m7frJgZl75Nj7S1nC/RfY=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    fixtures
    netaddr
    oslo-log
    oslo-serialization
    oslo-utils
    ovs
  ];

  nativeCheckInputs = [
    stestr
    oslotest
    testtools
    testscenarios
  ];

  checkPhase = ''
    runHook preCheck
    stestr run
    runHook postCheck
  '';

  pythonImportsCheck = [ "ovsdbapp" ];

  meta = with lib; {
    description = "A library for creating OVSDB applications";
    homepage = "https://github.com/openstack/ovsdbapp";
    license = licenses.asl20;
  };
}
