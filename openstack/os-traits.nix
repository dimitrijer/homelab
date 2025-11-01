{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, stestr
, oslotest
, testtools
, testscenarios
}:

buildPythonPackage rec {
  pname = "os-traits";
  version = "3.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "os-traits";
    rev = version;
    hash = "sha256-E2hO6tvMby3+g+e2iJxyjstOKc4abZn2z/WqCIpZH4A=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
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

  pythonImportsCheck = [ "os_traits" ];

  meta = with lib; {
    description = "OpenStack traits library";
    homepage = "https://github.com/openstack/os-traits";
    license = licenses.asl20;
  };
}
