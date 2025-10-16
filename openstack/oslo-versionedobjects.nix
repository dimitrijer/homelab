{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, iso8601
, netaddr
, oslo-concurrency
, oslo-config
, oslo-context
, oslo-i18n
, oslo-log
, oslo-messaging
, oslo-serialization
, oslo-utils
, webob
, stestr
, oslotest
, testtools
, fixtures
, jsonschema
}:

buildPythonPackage rec {
  pname = "oslo.versionedobjects";
  version = "3.8.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.versionedobjects";
    rev = version;
    hash = "sha256-ACAFuie6i7az34/UQKpL6xJJqaeFN5vPbX0j2a7PfxA=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    iso8601
    netaddr
    oslo-concurrency
    oslo-config
    oslo-context
    oslo-i18n
    oslo-log
    oslo-messaging
    oslo-serialization
    oslo-utils
    webob
  ];

  nativeCheckInputs = [
    stestr
    oslotest
    testtools
    fixtures
    jsonschema
  ];

  checkPhase = ''
    runHook preCheck
    stestr run
    runHook postCheck
  '';

  pythonImportsCheck = [ "oslo_versionedobjects" ];

  meta = with lib; {
    description = "Oslo Versioned Objects library";
    homepage = "https://github.com/openstack/oslo.versionedobjects";
    license = licenses.asl20;
  };
}
