{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, oslo-config
, oslo-context
, oslo-i18n
, oslo-serialization
, oslo-utils
, pyyaml
, requests
, stevedore
, stestr
, oslotest
, requests-mock
, sphinx
, docutils
}:

buildPythonPackage rec {
  pname = "oslo.policy";
  version = "4.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.policy";
    rev = version;
    hash = "sha256-+X5IRr0K1aeggZU7CSyYl5pe6UPLkKsp4ZV/+gKvnNQ=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    oslo-config
    oslo-context
    oslo-i18n
    oslo-serialization
    oslo-utils
    pyyaml
    requests
    stevedore
  ];

  nativeCheckInputs = [
    stestr
    oslotest
    requests-mock
    sphinx
    docutils
  ];

  checkPhase = ''
    runHook preCheck
    stestr run
    runHook postCheck
  '';

  pythonImportsCheck = [ "oslo_policy" ];

  meta = with lib; {
    description = "Oslo Policy library";
    homepage = "https://github.com/openstack/oslo.policy";
    license = licenses.asl20;
  };
}
