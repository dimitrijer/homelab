{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, pbr
, eventlet
, oslo-concurrency
, oslo-config
, oslo-i18n
, oslo-log
, oslo-utils
, paste
, pastedeploy
, routes
, webob
, yappi
, oslo-privsep
, stestr
, oslotest
, fixtures
, requests
, futurist
}:

buildPythonPackage rec {
  pname = "oslo.service";
  version = "4.3.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "openstack";
    repo = "oslo.service";
    rev = version;
    hash = "sha256-nFjCS7a6BzT/70lolIseH064OCoEXn5s1v+EOoFz1Fs=";
  };

  # pbr needs version information from git or env variable
  env.PBR_VERSION = version;

  build-system = [
    setuptools
    pbr
  ];

  dependencies = [
    eventlet
    oslo-concurrency
    oslo-config
    oslo-i18n
    oslo-log
    oslo-utils
    paste
    pastedeploy
    routes
    webob
    yappi
    oslo-privsep
  ];

  nativeCheckInputs = [
    stestr
    oslotest
    fixtures
    requests
    futurist
  ];

  # Tests require cotyledon which is not in nixpkgs
  doCheck = false;

  pythonImportsCheck = [ "oslo_service" ];

  meta = with lib; {
    description = "Oslo Service library";
    homepage = "https://github.com/openstack/oslo.service";
    license = licenses.asl20;
  };
}
